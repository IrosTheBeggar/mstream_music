#!/usr/bin/env bash
# Federation rig: two local mStream servers paired over the federation
# endpoint (peer A grants a library to parent B), parent B planted on the phone,
# and A browsed, played and downloaded THROUGH B's proxies — reached over plain
# HTTP on the LAN, or (SMOKE_RIG_IROH=1) over B's Quick Connect tunnel, so the
# peer rides the parent's loopback tunnel and the tunnel must survive a switch
# to a standard server while a peer track plays (the transport-aware tunnel
# target + queue listener, PR #129).
#
# Direct access (issue #143, mStream#943 + app PR #150): when the server build
# hands out guest tickets, the app dials the peer's federation endpoint itself
# and the peer's URLs move to its own loopback. Detected from the log (older
# servers are skipped, not failed) and checked: the ticket, the peer's own
# tunnel (`mode=guest`), the queued URLs moving over, the parent killed
# mid-track (the next track streams, the peer's API answers), the ticket
# renewed in place at 75% of its life when SMOKE_RIG_TTL_MS is set (default
# 180000; 0 = skip the renewal wait), and — in Quick Connect mode — the
# parent's tunnel released once the peer is direct and re-dialed for the
# renewal. SMOKE_RIG_REVOKE=1 (default) ends by revoking the key on A: the
# app must park without a crash or a hot loop.
#
# SMOKE_RIG_PA / SMOKE_RIG_PB pick the ports (3101/3102). SMOKE_RIG_SERVERS_ONLY=1
# starts and pairs the servers, prints their details as JSON, and leaves them
# up (no phone) — the iOS rounds drive the app by hand against them.
#
# Needs: a server checkout with node_modules (SMOKE_MSTREAM_SRC, default
# ~/code/mStream — a `git worktree` of the server's master works, with
# node_modules symlinked), node, a music folder (SMOKE_RIG_MUSIC, default
# ~/code/mstream-demo-music, ~10 albums), the phone on the Mac's LAN
# (SMOKE_RIG_HOST, default en0's address). Taps use the Galaxy S25 coordinates
# and assume the picker lists the parent first and the peer last.
#
# Everything it creates is torn down: both servers, their scratch dirs, the
# phone's server list (cfg_restore) and the peer's download folder.
#
# Taps are Galaxy S25 defaults. On the arm64 "smoke" AVD (Pixel 7 profile,
# 1080x2400) the peer's home grid sits lower and a track ROW tap only appends
# one track, so override: SMOKE_ALBUMS_ROW_XY="798 780" SMOKE_ALBUM1_XY="190 672"
# SMOKE_TRACK1_XY="746 341" (the album's Play button — what queues the album).
set -u
source "$(dirname "$0")/../lib.sh"
[ "${SMOKE_RIG_SERVERS_ONLY:-0}" = 1 ] || { pick_device; cfg_backup; }
SRC="${SMOKE_MSTREAM_SRC:-$HOME/code/mStream}"; MUSIC="${SMOKE_RIG_MUSIC:-$HOME/code/mstream-demo-music}"
HOST="${SMOKE_RIG_HOST:-$(ipconfig getifaddr en0)}"; IROH="${SMOKE_RIG_IROH:-0}"
PA=${SMOKE_RIG_PA:-3101}; PB=${SMOKE_RIG_PB:-3102}; RIG="$OUT/rig"; mkdir -p "$RIG"; J='Content-Type: application/json'
TTL=${SMOKE_RIG_TTL_MS:-180000}; REVOKE=${SMOKE_RIG_REVOKE:-1}
[ "$TTL" != 0 ] && export MSTREAM_TEST_FED_GUEST_TTL_MS=$TTL
PICKER=${SMOKE_PICKER_XY:-"1007 187"}; ALBUMS_ROW=${SMOKE_ALBUMS_ROW_XY:-"234 909"}
ALBUM1=${SMOKE_ALBUM1_XY:-"278 708"}; TRACK1=${SMOKE_TRACK1_XY:-"468 886"}
[ -f "$SRC/cli-boot-wrapper.js" ] && [ -d "$SRC/node_modules" ] || { echo "no server checkout with node_modules at $SRC"; exit 2; }
[ -d "$MUSIC" ] || { echo "no music folder at $MUSIC"; exit 2; }
NODES=""
cleanup() {
  [ -n "$NODES" ] && kill $NODES 2>/dev/null
  adbx shell "run-as $PKG rm -rf app_flutter/media/peer-rig-peer-a" 2>/dev/null
  cfg_restore
}
trap cleanup EXIT

# ── the two servers ────────────────────────────────────────────────────────
rig_cfg() { # <name> <port> <bind address> <folder path>
  python3 - "$RIG/$1" "$2" "$3" "$4" "$5" <<'PY'
import json,os,sys
d,port,addr,root,name=sys.argv[1:]; os.makedirs(d, exist_ok=True)
st={k: os.path.join(d,v) for k,v in dict(albumArtDirectory='image-cache', dbDirectory='db', logsDirectory='logs', waveformCacheDirectory='waveform-cache').items()}
for p in st.values(): os.makedirs(p, exist_ok=True)
json.dump({"port":int(port),"address":addr,"ui":"default","folders":{"demo":{"root":root}},"storage":st,
  "federation":{"enabled":True,"serverName":name},
  "scanOptions":{"autoAlbumArt":False,"collectDiscoveryData":False,"analyzeBpm":False},
  "discoveryP2p":{"seedListUrl":"http://127.0.0.1:9/discovery-seeds.json","useCommunitySeeds":False}},
  open(os.path.join(d,'config.json'),'w'), indent=2)
PY
}
rig_cfg a $PA 127.0.0.1 "$MUSIC" "Rig Peer A"
rig_cfg b $PB 0.0.0.0 "$MUSIC/$(ls "$MUSIC" | head -1)" "Rig Parent B"
export NODE_ENV=test MSTREAM_TEST_BAKED_SEEDS='[]' MSTREAM_SIDECAR_BASE=http://127.0.0.1:9 MSTREAM_PLAYER_BASE=http://127.0.0.1:9
# exec, so $! is node itself and the cleanup kill reaches it, not a wrapper shell
( cd "$SRC" && exec node cli-boot-wrapper.js -j "$RIG/a/config.json" > "$RIG/a.log" 2>&1 ) & NODES="$!"
( cd "$SRC" && exec node cli-boot-wrapper.js -j "$RIG/b/config.json" > "$RIG/b.log" 2>&1 ) & NODES="$NODES $!"
for i in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PA/api/)" = 200 ] && [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PB/api/)" = 200 ] && break; sleep 2
done
[ "$i" -lt 60 ] && pass "both servers up (${i}x2s)" || { fail "servers did not come up (see $RIG/*.log)"; summary; exit 1; }
sleep 8 # boot scan of the demo folder

# ── pair them: users, a key minted on A, the ticket added on B ─────────────
for p in $PA $PB; do curl -s -o /dev/null -X PUT "http://127.0.0.1:$p/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["demo"],"admin":true}'; done
tok() { curl -s -X POST "http://127.0.0.1:$1/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])"; }
TA=$(tok $PA); TB=$(tok $PB)
TICKET=$(curl -s -X POST "http://127.0.0.1:$PA/api/v1/admin/federation/keys" -H "$J" -H "x-access-token: $TA" -d '{"name":"Rig Parent B","vpaths":["demo"]}' | python3 -c "import sys,json; print(json.load(sys.stdin)['ticket'])")
PEER=$(curl -s -X POST "http://127.0.0.1:$PB/api/v1/admin/federation/peers" -H "$J" -H "x-access-token: $TB" -d "{\"ticket\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TICKET")}")
PEER_ID=$(echo "$PEER" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
STATUS=$(curl -s "http://127.0.0.1:$PB/api/v1/federation/peers" -H "x-access-token: $TB" | python3 -c "import sys,json; p=json.load(sys.stdin)['peers']; print(p[0]['lastStatus'] if p else 'none')")
[ "$STATUS" = ok ] && pass "B dialed A over the federation endpoint (peer id $PEER_ID, status ok)" || fail "peer status on B: $STATUS"
VIA=$(curl -s "http://127.0.0.1:$PB/api/v1/federation/peers/$PEER_ID/api/api/" -H "x-access-token: $TB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('server'), d.get('user',{}).get('vpaths'))")
case "$VIA" in *"['demo']"*) pass "proxied /api/ reaches A scoped to the granted library ($VIA)";; *) fail "proxied /api/ answered: $VIA";; esac
KEY_ID=$(curl -s "http://127.0.0.1:$PA/api/v1/admin/federation/keys" -H "x-access-token: $TA" | python3 -c "import sys,json; k=json.load(sys.stdin); k=k.get('keys', k) if isinstance(k, dict) else k; print(k[0]['id'] if k else '')" 2>/dev/null)
if [ "${SMOKE_RIG_SERVERS_ONLY:-0}" = 1 ]; then
  trap - EXIT; cfg_restore >/dev/null 2>&1
  python3 -c "import json,sys; print(json.dumps(dict(peerPort=int('$PA'), parentPort=int('$PB'), host='$HOST', parentToken='$TB', peerToken='$TA', peerId='$PEER_ID', keyId='$KEY_ID', pids='$NODES', parentConfig='$RIG/b/config.json', src='$SRC'), indent=1))"
  log "servers-only: A $PA and B $PB left up (pids $NODES); kill them yourself"; summary; exit 0
fi

# ── the parent on the phone ────────────────────────────────────────────────
if [ "$IROH" = 1 ]; then
  # A just-enabled endpoint stalls the phone's first dials in the handshake
  # (mStream#940; six 13s stalls in a row on 2026-09-05): give it a moment
  # to settle on its relay before the phone comes knocking.
  curl -s -o /dev/null -X POST "http://127.0.0.1:$PB/api/v1/admin/iroh" -H "$J" -H "x-access-token: $TB" -d '{"enabled":true}'; sleep "${SMOKE_RIG_QC_WARMUP:-15}"
  CODE=$(curl -s "http://127.0.0.1:$PB/api/v1/admin/iroh" -H "x-access-token: $TB" | python3 -c "import sys,json; print(json.load(sys.stdin).get('qr') or '')")
  [ -n "$CODE" ] && pass "Quick Connect up on B" || { fail "no pairing code from B"; summary; exit 1; }
  PARENT=iroh-rig-b; URL="iroh://rig-b"; CT=iroh
else
  CODE=""; PARENT=rig-b; URL="http://$HOST:$PB"; CT=http
fi
python3 - "$CFG_BACKUP/servers.json" "$RIG/servers.json" "$URL" "$TB" "$PARENT" "$CT" "$CODE" <<'PY'
import json,sys
src,dst,url,tok,name,ct,code=sys.argv[1:]
L=json.load(open(src))
b={"url":url,"jwt":tok,"username":"rig","password":"rigpw","localname":name,"autoDJPaths":{},"autoDJminRating":None,"autoDJGenreEnabled":False,"autoDJGenreMode":"whitelist","autoDJGenres":[],"playlists":[],"allowSelfSigned":False,"storageMode":"appLocal","storageBasePath":None,"transcodeAvailable":None,"transcodeDefaultCodec":None,"transcodeDefaultBitrate":None,"discoveryAvailable":None,"federationDiscoveryAvailable":None,"discoveryPathAvailable":None,"connectionType":ct,"irohPairingCode":code or None,"serverVersion":None,"versionCheckedAt":None}
json.dump([b]+L, open(dst,'w'))
PY
app_stop; cfg_write servers.json "$RIG/servers.json"; logcat_clear; wake; app_start
wait_for_log '\[app\] default server ready' 30 || fail "default never published"
# The reconcile runs once the parent's capability refresh lands; over a
# just-enabled Quick Connect the first dials stall in the handshake for ~13s
# each (mStream#940) — four in a row on 2026-09-05 — and the retry ladder
# (2/10/20/40/60s) needs ~200s to get through that, so allow it.
[ "$IROH" = 1 ] && RECON=200 || RECON=90
for i in $(seq 1 $RECON); do
  cfg_read servers.json | python3 -c "import sys,json; sys.exit(0 if any(s.get('federationParent')=='$PARENT' for s in json.load(sys.stdin)) else 1)" && break; sleep 1
done
[ "$i" -lt "$RECON" ] && pass "peer reconciled under $PARENT in ${i}s" || { save_applog rig-launch; fail "no peer entry after ${RECON}s"; summary; exit 1; }
N=$(cfg_read servers.json | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
PEER_Y=$((222 + 144 * (N - 1))) # picker rows: 222, 366, 510, … — the peer is listed last
tap $PICKER; sleep 1.5; shot picker; tap 639 $PEER_Y; sleep 3
wait_for_log '\[srv\] switched to peer-rig-peer-a' 5 && pass "peer selected from the picker" || fail "no switch to the peer"
shot peer-nav
tap $ALBUMS_ROW; sleep 4; shot peer-albums; tap $ALBUM1; sleep 3; tap $TRACK1; sleep 6
if wait_for_log '\[queue\] add [0-9]+ tracks' 5 && is_playing; then pass "peer album queued and playing through the stream proxy ($(session_state))"; else save_applog rig-play; fail "peer track did not play ($(session_state))"; fi
shot peer-playing
adbx shell "run-as $PKG test -d app_flutter/media/peer-rig-peer-a" && pass "download folder created for the peer" || fail "no media/peer-rig-peer-a folder"

# ── direct access: the peer over a tunnel of its own ─────────────────────
PEER_LN=peer-rig-peer-a; PB_PID=${NODES##* }; A_PID=${NODES%% *}
restart_b() { # the parent again, same config and env; the access cache starts empty
  ( cd "$SRC" && exec node cli-boot-wrapper.js -j "$RIG/b/config.json" >> "$RIG/b.log" 2>&1 ) & PB_PID=$!; NODES="$A_PID $PB_PID"
  for i in $(seq 1 40); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PB/api/)" != 000 ] && break; sleep 1; done
  log "parent B back (pid $PB_PID) after ${i}s"
}
peer_port() { applog | grep -oE "tunnel up port=[0-9]+ .*for=$PEER_LN" | tail -1 | grep -oE 'port=[0-9]+' | cut -d= -f2; }
DIRECT=0
if wait_for_log "\[federation\] $PEER_LN: direct access issued" 30; then DIRECT=1; pass "guest ticket issued by the parent"
elif applog | grep -q "no direct access"; then skip "the parent declined direct access ($(applog | grep -oE 'no direct access \([^)]*\)' | head -1)) — proxy path only"
else skip "no direct access from this server build — proxy path only"; fi
if [ "$DIRECT" = 1 ]; then
  # Two 13s handshake stalls on the first dial are the mStream#940 kind (the retry ladder lands it).
  if wait_for_log "\[iroh\] tunnel up .*for=$PEER_LN" 120; then
    PPORT=$(peer_port); pass "peer tunnel up on its own port $PPORT ($(applog | grep -oE 'mode=guest' | head -1 || echo 'mode?'), $(applog | grep -oE "tunnel up .*for=$PEER_LN" | tail -1 | grep -oE 'path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\)'))"
  else fail "peer tunnel did not come up within 120s"; fi
  # Queued URLs move to the peer's loopback on the bind (upcoming items; the
  # playing one keeps its stream). Downloaded copies keep their stored URL by
  # design, so only items still streaming count, and the queue file is
  # written a moment after the rebuild — poll for it.
  moved() { cfg_read queue.json | python3 -c "
import sys,json
from urllib.parse import urlparse
d=json.load(sys.stdin); items=d.get('items') or []; cur=d.get('index',0); on=off=0
for i,it in enumerate(items):
    if i <= cur or (it.get('extras') or {}).get('localPath'): continue
    u=urlparse(it.get('id',''))
    if u.hostname=='127.0.0.1' and u.port==int('${PPORT:-0}') and u.path.startswith('/media/') and 'token=' in u.query and '__lt=' in u.query: on+=1
    else: off+=1
print(on, off)" 2>/dev/null; }
  for i in $(seq 1 25); do set -- $(moved); [ "${1:-0}" -ge 1 ] && [ "${2:-1}" -eq 0 ] && break; sleep 1; done
  set -- $(moved); [ "${1:-0}" -ge 1 ] && [ "${2:-1}" -eq 0 ] && pass "$1 upcoming streaming URLs on the peer's loopback (/media, guest token, own __lt), none left on the proxy" || fail "upcoming URLs: ${1:-0} on the peer's loopback, ${2:-?} still on the proxy after 25s"
  if [ "$IROH" = 1 ]; then
    # The parent's tunnel is only a target while the peer is not direct (and for the access call).
    wait_for_log "tunnel stopped .*for=$PARENT" 45 && pass "parent's tunnel released once the peer went direct" || fail "parent's tunnel still up 45s after the peer went direct"
  fi
  # The parent dies mid-track: the peer keeps serving — the next track streams
  # from the peer's loopback and the peer's API answers over the same tunnel.
  kill "$PB_PID"; sleep 1; NODES="$A_PID"
  adbx shell input keyevent 87; sleep 8
  if is_playing; then pass "next track plays with the parent dead ($(session_state))"; else save_applog rig-parent-dead; fail "playback lost with the parent dead ($(session_state))"; fi
  tap 93 337; sleep 2; T=$(now_ts); tap $ALBUM1; sleep 4
  wait_for_log_after "$T" '\[api\] POST /api/v1/file-explorer → 200' 5 && pass "peer's file explorer answers 200 over the direct tunnel with the parent dead" || fail "no 200 from the peer's API with the parent dead"
  restart_b
  if [ "$TTL" != 0 ]; then
    # Renewed in place at 75% of the ticket's life; the port is kept.
    WAIT=$(( TTL * 3 / 4000 + 100 ))
    if wait_for_log "guest credential refreshed in place \(stale\) for=$PEER_LN" $WAIT; then
      UPS=$(count_log "tunnel up .*for=$PEER_LN"); [ "$UPS" -eq 1 ] && pass "guest ticket renewed in place, port $PPORT kept" || fail "renewal rotated the peer's tunnel ($UPS tunnel-ups)"
      if [ "$IROH" = 1 ]; then
        [ "$(count_log "tunnel up .*for=$PARENT")" -ge 2 ] && pass "parent's Quick Connect tunnel re-dialed for the access call" || fail "the renewal did not re-dial the parent's tunnel"
      fi
    else save_applog rig-renewal; fail "no in-place renewal within ${WAIT}s (TTL ${TTL}ms)"; fi
  fi
fi
if [ "$IROH" = 1 ]; then
  # The tunnel that carries the peer: the PARENT's on the proxy path, the
  # PEER's own once direct (the parent's is released then — checked above).
  # A Quick Connect queue the peer album replaced is released after the grace
  # (`tunnel stopped (no-target/queue-server) … for=<that server>`), which is
  # correct. Old builds log no `for=` suffix; their single tunnel is the parent.
  if [ "$DIRECT" = 1 ]; then CARRIER=$PEER_LN; else CARRIER=$PARENT; fi
  carrier_stops() { count_log "tunnel stopped .*(for=$CARRIER\$|port=[0-9a-z]+\$)"; }
  STOPS0=$(carrier_stops)
  [ "$DIRECT" = 1 ] || { [ "$STOPS0" -eq 0 ] && pass "browsing the peer kept the parent's tunnel" || fail "the parent's tunnel was stopped while the peer was browsed"; }
  # switch to the first standard server (row 2) while the peer track plays
  T=$(now_ts); tap $PICKER; sleep 1.5; tap 782 366; sleep 5
  wait_for_log_after "$T" '\[srv\] switched to ' 5 || fail "no switch away from the peer"
  if is_playing && [ "$(carrier_stops)" -eq "$STOPS0" ]; then pass "$CARRIER's tunnel kept for the queued peer track after switching to a standard server"; else fail "tunnel or playback lost after the switch ($(session_state), $(( $(carrier_stops) - STOPS0 )) $CARRIER stop(s))"; fi
  # Phase 4: relaunch with the peer track queued. The parent's tunnel comes up on
  # a FRESH port, so the restored peer URLs (stream through the parent's proxy,
  # art through its art proxy) must be re-derived against it — or the track
  # plays from a dead loopback port.
  PORT1=$(applog | grep -oE "tunnel up port=[0-9]+ .*for=$CARRIER" | head -1 | grep -oE 'port=[0-9]+' | cut -d= -f2)
  media_key pause; sleep 1; app_stop; logcat_clear; wake; app_start
  wait_for_log "\[iroh\] tunnel up .*for=$CARRIER" 120 || fail "no $CARRIER tunnel after the relaunch"
  PORT2=$(applog | grep -oE "tunnel up port=[0-9]+ .*for=$CARRIER" | head -1 | grep -oE 'port=[0-9]+' | cut -d= -f2)
  # The restored track must be the PEER's (a leftover queue from another
  # server would pass a bare "track N/M" check), on the parent's FRESH port.
  if wait_for_log '\[play\] track [0-9]+/[0-9]+' 30; then
    sleep 3
    RESTORED=$(cfg_read queue.json | python3 -c "
import sys,json
from urllib.parse import urlparse
d=json.load(sys.stdin); it=(d.get('items') or [])[d.get('index',0)]
print((it.get('extras') or {}).get('server'), urlparse(it.get('id','')).port)" 2>/dev/null)
    if [ "$RESTORED" = "peer-rig-peer-a $PORT2" ] && ensure_playing 15; then pass "restored peer track plays after a relaunch on $CARRIER's fresh port ($PORT1 → $PORT2)"
    else save_applog rig-relaunch; fail "restored track is not the peer's on the fresh port (got '$RESTORED', port $PORT2; $(session_state))"; fi
  else save_applog rig-relaunch; fail "queue did not restore after the relaunch"; fi
fi
# ── the key revoked on A: everything must park without a crash or a hot loop ─
if [ "$DIRECT" = 1 ] && [ "$REVOKE" = 1 ] && [ -n "$KEY_ID" ]; then
  media_key play; sleep 2
  PID0=$(adbx shell pidof "$PKG" | tr -d '\r'); N0=$(applog | wc -l | tr -d ' ')
  curl -s -o /dev/null -X DELETE "http://127.0.0.1:$PA/api/v1/admin/federation/keys/$KEY_ID" -H "x-access-token: $TA"
  log "key $KEY_ID revoked on A"; sleep 3; adbx shell input keyevent 87; sleep 72   # NEXT: a fresh request, not a buffered track
  PID1=$(adbx shell pidof "$PKG" | tr -d '\r')
  [ -n "$PID1" ] && [ "$PID1" = "$PID0" ] && pass "app alive 75s after the revocation (pid $PID1)" || fail "app died or restarted after the revocation ($PID0 → $PID1)"
  FED=$(applog | tail -n +$N0 | grep -cE "\[federation\]|\[api\].*401"); RES=$(applog | tail -n +$N0 | grep -c "resuming parked playback")
  [ "$FED" -le 12 ] && [ "$RES" -le 8 ] && pass "no hot loop after the revocation ($FED access/401 lines, $RES heal resumes in 75s)" || fail "loop after the revocation ($FED access/401 lines, $RES heal resumes in 75s)"
  WALK=$(applog | tail -n +$N0 | grep -oE 'failedSkips=[0-9]+' | tail -1 | cut -d= -f2)
  case "$(session_state)" in
    *PLAYING*) [ "${WALK:-0}" -ge 3 ] && pass "the failure walk is running after the revocation (failedSkips=$WALK)" || fail "still PLAYING 75s after the revocation with no walk (failedSkips=${WALK:-0})";;
    *) pass "playback parked after the revocation ($(session_state), failedSkips=${WALK:-0})";;
  esac
  log "after revocation: $(applog | tail -n +$N0 | grep -oE "\[iroh\] status [a-z]+ → [a-z]+ .*for=$PEER_LN" | tail -1)"
fi
media_key pause; sleep 1
save_applog federation-rig
# SMOKE_RIG_KEEP=1: leave both servers running and the phone on the rig config
# for checks done by hand afterwards (restore with cfg_restore + kill the nodes).
if [ "${SMOKE_RIG_KEEP:-0}" = 1 ]; then trap - EXIT; log "kept: servers $NODES up, phone on the rig config, backup in $CFG_BACKUP"; fi
summary
