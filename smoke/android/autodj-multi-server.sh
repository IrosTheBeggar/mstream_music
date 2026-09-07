#!/usr/bin/env bash
# Multi-server Auto DJ (app PR #128 on mStream #929/#946): one session draws
# its picks from EVERY eligible server, seeded by a vector read from the
# anchor's own server, best cosine wins. Two local mStream servers scanned
# under the server's `test-fake` discovery model (8-d, deterministic, no
# model download), three phases:
#   1. federated  — parent B on the phone, peer A reconciled through B; the DJ
#                   armed on B with sonic + "Play from every server" on; the
#                   queue-end top-up must ask both servers and queue the best
#                   answer, which must then play (a peer pick streams through
#                   the proxy or the peer's own tunnel).
#   1b. hosted on the peer — the DJ armed ON peer A (Scope 1 of mStream #936),
#                   fan-out off: a sonic pick from the peer's own library,
#                   seeded by filepath, through the proxy or its own tunnel.
#   2. own servers — A and B planted directly (the pairing removed); the same
#                   over the app's own server list.
#   3. Quick Connect fan-out — A is the DJ server (HTTP), B a Quick Connect
#                   entry that is neither browsed nor queued: arming the
#                   session must dial B's tunnel by itself (tunnel-follows-
#                   the-DJ), and the pick must answer 2/2 over it.
#   4. DJ off — the mini-player's Auto DJ pill switches the session off; B's
#                   tunnel must be released at once (`tunnel stopped
#                   (no-target/dj-off)`) and not re-dialed. Skipped when the
#                   phase-3 pick came from B: a queued track keeps its tunnel.
#
# Pass lines to look for in the app log: `[dj] <server> answers in model
# test-fake (N analysed)` (the health handshake), `[dj] multi-server: 2/2
# answered, … best 0.xxxx from <server>`, then `[queue] add: <title>` and the
# pick playing.
#
# Needs what federation-rig.sh needs (SMOKE_MSTREAM_SRC with node_modules,
# SMOKE_RIG_MUSIC, the phone on the Mac's LAN). The servers must REPORT a
# version at or above the app's vector-seed floor (6.26.0 while that release
# is still expected — bump the checkout's package.json for the run; the
# script says so when they don't). SMOKE_RIG_SERVERS_ONLY=1 boots and pairs
# the servers, prints their ports and leaves them up for the iOS rounds.
#
# Taps are Galaxy S25 defaults (home grid Albums tile, first album, a track
# row — which queues the whole album — and the mini-player's Auto DJ pill).
# Override with SMOKE_HOME_ALBUMS_XY, SMOKE_ALBUM1_XY, SMOKE_TRACK1_XY,
# SMOKE_DJ_PILL_XY, SMOKE_PEER_ALBUMS_XY for other phones.
set -u
source "$(dirname "$0")/../lib.sh"
[ "${SMOKE_RIG_SERVERS_ONLY:-0}" = 1 ] || { pick_device; cfg_backup; }
SRC="${SMOKE_MSTREAM_SRC:-$HOME/code/mStream}"; MUSIC="${SMOKE_RIG_MUSIC:-$HOME/code/mstream-demo-music}"
HOST="${SMOKE_RIG_HOST:-$(ipconfig getifaddr en0)}"
PA=${SMOKE_RIG_PA:-3101}; PB=${SMOKE_RIG_PB:-3102}; RIG="$OUT/rig"; mkdir -p "$RIG"; J='Content-Type: application/json'
HOME_ALBUMS=${SMOKE_HOME_ALBUMS_XY:-"281 1030"}; ALBUM1=${SMOKE_ALBUM1_XY:-"278 708"}; TRACK1=${SMOKE_TRACK1_XY:-"468 886"}
# The peer's home carries a "Read-only server" note above its grid, which
# drops the Playlists/Rated tiles and puts Albums top-RIGHT (Galaxy: 796 842).
PEER_ALBUMS=${SMOKE_PEER_ALBUMS_XY:-"796 842"}
PICKER=${SMOKE_PICKER_XY:-"1007 187"}; DJ_PILL=${SMOKE_DJ_PILL_XY:-"944 2118"}
FLOOR=${SMOKE_DJ_FLOOR:-6.26.0}
[ -f "$SRC/cli-boot-wrapper.js" ] && [ -d "$SRC/node_modules" ] || { echo "no server checkout with node_modules at $SRC"; exit 2; }
[ -d "$MUSIC" ] || { echo "no music folder at $MUSIC"; exit 2; }
NODES=""
cleanup() {
  [ -n "$NODES" ] && kill $NODES 2>/dev/null
  [ "${SMOKE_RIG_SERVERS_ONLY:-0}" = 1 ] && return 0
  for d in peer-rig-peer-a rig-a rig-b iroh-rig-b; do adbx shell "run-as $PKG rm -rf app_flutter/media/$d" 2>/dev/null; done
  cfg_restore
}
trap cleanup EXIT

# ── the two servers, discovery on under the fake model ─────────────────────
rig_cfg() { # <name> <port> <folder path> <server name>
  python3 - "$RIG/$1" "$2" "$3" "$4" <<'PY'
import json,os,sys
d,port,root,name=sys.argv[1:]; os.makedirs(d, exist_ok=True)
st={k: os.path.join(d,v) for k,v in dict(albumArtDirectory='image-cache', dbDirectory='db', logsDirectory='logs', waveformCacheDirectory='waveform-cache').items()}
for p in st.values(): os.makedirs(p, exist_ok=True)
json.dump({"port":int(port),"address":"0.0.0.0","ui":"default","folders":{"demo":{"root":root}},"storage":st,
  "federation":{"enabled":True,"serverName":name},
  "scanOptions":{"autoAlbumArt":False,"collectDiscoveryData":True,"discoveryModel":"test-fake","analyzeBpm":False},
  "discoveryP2p":{"seedListUrl":"http://127.0.0.1:9/discovery-seeds.json","useCommunitySeeds":False}},
  open(os.path.join(d,'config.json'),'w'), indent=2)
PY
}
# Disjoint libraries — so a pick from the other server is a track this one
# does not hold: B gets the first top-level folder, A the largest of the rest
# (a real folder: the scanner does not follow a directory of symlinks).
FIRST=$(ls "$MUSIC" | head -1)
SECOND=$(python3 -c "
import os,sys
m,first=sys.argv[1:]; ext=('.mp3','.flac','.m4a','.ogg','.opus','.wav')
best=max((sum(1 for _,_,fs in os.walk(os.path.join(m,d)) for f in fs if f.lower().endswith(ext)), d) for d in os.listdir(m) if d != first and os.path.isdir(os.path.join(m,d)))
print(best[1])" "$MUSIC" "$FIRST")
log "libraries: A = $SECOND, B = $FIRST"
rig_cfg a $PA "$MUSIC/$SECOND" "Rig Peer A"
rig_cfg b $PB "$MUSIC/$FIRST" "Rig Parent B"
export NODE_ENV=test MSTREAM_TEST_BAKED_SEEDS='[]' MSTREAM_SIDECAR_BASE=http://127.0.0.1:9 MSTREAM_PLAYER_BASE=http://127.0.0.1:9
( cd "$SRC" && exec node cli-boot-wrapper.js -j "$RIG/a/config.json" > "$RIG/a.log" 2>&1 ) & NODES="$!"
( cd "$SRC" && exec node cli-boot-wrapper.js -j "$RIG/b/config.json" > "$RIG/b.log" 2>&1 ) & NODES="$NODES $!"
for i in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PA/api/)" = 200 ] && [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PB/api/)" = 200 ] && break; sleep 2
done
[ "$i" -lt 60 ] && pass "both servers up (${i}x2s)" || { fail "servers did not come up (see $RIG/*.log)"; summary; exit 1; }
VER=$(curl -s http://127.0.0.1:$PB/api/ | python3 -c "import sys,json; print(json.load(sys.stdin).get('server',''))")
python3 -c "
import sys
v=lambda s: tuple(int(x) for x in s.split('.')[:3])
sys.exit(0 if v(sys.argv[1]) >= v(sys.argv[2]) else 1)" "$VER" "$FLOOR" && pass "servers report $VER (app floor $FLOOR)" \
  || { fail "servers report $VER, below the app's vector-seed floor $FLOOR — every server would sit out (bump $SRC/package.json for the run)"; summary; exit 1; }
for p in $PA $PB; do curl -s -o /dev/null -X PUT "http://127.0.0.1:$p/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["demo"],"admin":true}'; done
tok() { curl -s -X POST "http://127.0.0.1:$1/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])"; }
TA=$(tok $PA); TB=$(tok $PB)
# The embedding pass runs after the boot scan (and after ffmpeg resolves);
# wait until each server's analysed count has stopped growing.
analysed() { curl -s "http://127.0.0.1:$1/api/v1/federation/health" -H "x-access-token: $2" | python3 -c "import sys,json; d=json.load(sys.stdin).get('discovery'); print(d['analyzedCount'] if d else 0)" 2>/dev/null; }
wait_analysed() { # <port> <token> <label>
  local last=-1 same=0 n i
  for i in $(seq 1 90); do
    n=$(analysed "$1" "$2"); n=${n:-0}
    if [ "$n" -gt 0 ] && [ "$n" = "$last" ]; then same=$((same+1)); [ "$same" -ge 3 ] && break; else same=0; fi
    last=$n; sleep 2
  done
  [ "${n:-0}" -gt 0 ] && pass "$3: $n tracks analysed under test-fake" || fail "$3: nothing analysed after 180s"
  ANALYSED=${n:-0}
}
wait_analysed $PA "$TA" "peer A"; NA=$ANALYSED; wait_analysed $PB "$TB" "parent B"; NB=$ANALYSED
# The readiness flag the app gates sonic mode on (mStream #879): true once
# the pass has produced vectors — and it was false while the pass ran.
READY=$(curl -s "http://127.0.0.1:$PB/api/" -H "x-access-token: $TB" | python3 -c "import sys,json; print(json.load(sys.stdin).get('features',{}).get('discoveryReady'))")
[ "$READY" = True ] && pass "B reports discoveryReady after the pass (the app's sonic gate reads it)" || fail "B reports discoveryReady=$READY after the pass"

# ── pair them (A grants B its library) ─────────────────────────────────────
TICKET=$(curl -s -X POST "http://127.0.0.1:$PA/api/v1/admin/federation/keys" -H "$J" -H "x-access-token: $TA" -d '{"name":"Rig Parent B","vpaths":["demo"]}' | python3 -c "import sys,json; print(json.load(sys.stdin)['ticket'])")
PEER=$(curl -s -X POST "http://127.0.0.1:$PB/api/v1/admin/federation/peers" -H "$J" -H "x-access-token: $TB" -d "{\"ticket\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TICKET")}")
PEER_ID=$(echo "$PEER" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
STATUS=$(curl -s "http://127.0.0.1:$PB/api/v1/federation/peers" -H "x-access-token: $TB" | python3 -c "import sys,json; p=json.load(sys.stdin)['peers']; print(p[0]['lastStatus'] if p else 'none')")
[ "$STATUS" = ok ] && pass "B dialed A over the federation endpoint (peer id $PEER_ID)" || fail "peer status on B: $STATUS"
PH=$(curl -s "http://127.0.0.1:$PB/api/v1/federation/peers/$PEER_ID/api/api/v1/federation/health" -H "x-access-token: $TB" | python3 -c "import sys,json; d=json.load(sys.stdin).get('discovery') or {}; print(d.get('modelId'), d.get('analyzedCount'))")
[ "${PH%% *}" = test-fake ] && pass "peer's health through the proxy names its model ($PH)" || fail "proxied health: $PH"
if [ "${SMOKE_RIG_SERVERS_ONLY:-0}" = 1 ]; then
  trap - EXIT
  python3 -c "import json; print(json.dumps(dict(peerPort=int('$PA'), parentPort=int('$PB'), host='$HOST', parentToken='$TB', peerToken='$TA', peerId='$PEER_ID', pids='$NODES', analysed=dict(a=int('${NA:-0}'), b=int('${NB:-0}'))), indent=1))"
  log "servers-only: A $PA and B $PB left up (pids $NODES); kill them yourself"; summary; exit 0
fi

# ── helpers for the phases ─────────────────────────────────────────────────
server_json() { # <localname> <url> <token> <connectionType> <code>
  python3 -c "
import json,sys
n,u,t,ct,code=sys.argv[1:]
print(json.dumps({'url':u,'jwt':t,'username':'rig','password':'rigpw','localname':n,'autoDJPaths':{},'autoDJminRating':None,'autoDJGenreEnabled':False,'autoDJGenreMode':'whitelist','autoDJGenres':[],'playlists':[],'allowSelfSigned':False,'storageMode':'appLocal','storageBasePath':None,'transcodeAvailable':None,'transcodeDefaultCodec':None,'transcodeDefaultBitrate':None,'discoveryAvailable':None,'federationDiscoveryAvailable':None,'discoveryPathAvailable':None,'connectionType':ct,'irohPairingCode':code or None,'serverVersion':None,'versionCheckedAt':None}))" "$@"
}
plant() { # <dj localname> <server json>...
  local dj="$1"; shift
  printf '%s\n' "$@" | python3 -c "import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()]))" > "$RIG/servers.json"
  python3 - "$CFG_BACKUP/auto_dj.json" "$dj" "$RIG/auto_dj.json" <<'PY'
import json,sys
src,dj,dst=sys.argv[1:]
try: d=json.load(open(src))
except Exception: d={}
d.update(enabledServer=dj, multiServerEnabled=True, sonicSimilarityEnabled=True, sonicMinSimilarity=0.05,
         sonicAnchorMode='rolling', sonicSeedPath=None, sonicSeedTitle=None, sonicSeedServer=None,
         bpmContinuityEnabled=False, harmonicMixingEnabled=False, keywordFilterEnabled=False, durationFilterEnabled=False)
json.dump(d, open(dst,'w'))
PY
  app_stop; cfg_write servers.json "$RIG/servers.json"; cfg_write auto_dj.json "$RIG/auto_dj.json"; logcat_clear; wake; app_start
  wait_for_log '\[app\] default server ready' 30 || fail "default never published"
  wait_for_log "\[autodj\] restored on $dj" 15 && pass "DJ restored armed on $dj" || fail "DJ not restored on $dj"
}
play_album() { # tap the home grid's Albums tile → first album → a track row (queues the album); sets TRACKS
  tap $HOME_ALBUMS; sleep 4; shot "$1-albums"; tap $ALBUM1; sleep 3; tap $TRACK1; sleep 6
  local n; n=$(applog | grep -oE '\[queue\] add [0-9]+ tracks' | tail -1 | grep -oE '[0-9]+' | head -1)
  if [ -n "$n" ] && ensure_playing 15; then pass "$1: album queued ($n tracks) and playing ($(session_state))"; else save_applog "$1-play"; fail "$1: album did not play ($(session_state))"; fi
  TRACKS=${n:-0}
}
# Reach the last track (the queue-end top-up fires when it becomes current), then
# expect ONE cross-server pick: the handshake line for both servers, the
# fan-out line naming a winner, the winner's track queued and playable.
expect_pick() { # <phase> <track count> <server a localname> <server b localname>
  local ph="$1" n="$2" sa="$3" sb="$4" i T line who total ans usable
  T=$(now_ts)
  for i in $(seq 2 "$n"); do adbx shell input keyevent 87; sleep 1.5; done
  if wait_for_log_after "$T" '\[dj\] multi-server: [0-9]+/[0-9]+ answered' 90; then
    line=$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -oE '\[dj\] multi-server: [0-9]+/[0-9]+ answered, [0-9]+ usable, best [0-9.-]+ from [^ ]+' | head -1)
    ans=$(echo "$line" | grep -oE '[0-9]+/[0-9]+' | head -1); total=${ans#*/}; who=${line##* }
    [ "$ans" = "2/2" ] && pass "$ph: both servers answered — $line" || fail "$ph: not every server answered — $line"
    local hs; hs=$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -cE "\[dj\] ($sa|$sb) answers in model test-fake")
    [ "$hs" -ge 1 ] && pass "$ph: model handshake logged for $hs server(s) this pick" || log "note: no fresh handshake line this pick (cached from an earlier one)"
    if wait_for_log_after "$T" '\[queue\] add: ' 20; then
      # The queue file is written a moment after the append: poll until the
      # last item carries the DJ badge, so the server read is the pick's.
      local srv=""
      for i in $(seq 1 10); do
        srv=$(cfg_read queue.json | python3 -c "
import sys,json
d=json.load(sys.stdin); it=(d.get('items') or [])[-1]; ex=it.get('extras') or {}
print(ex.get('server'), ex.get('djPick'), ex.get('djSonic'))" 2>/dev/null)
        case "$srv" in *" True True") break;; esac; sleep 1
      done
      [ "${srv%% *}" = "$who" ] && [ "${srv#* }" = "True True" ] && pass "$ph: the winner's track ($who) is the queued pick (djPick + djSonic set)" || fail "$ph: queued pick reads '$srv', the fan-out said $who"
      T2=$(now_ts); adbx shell input keyevent 87; sleep 8
      if wait_for_log_after "$T2" '\[play\] track [0-9]+/[0-9]+' 10 && is_playing; then pass "$ph: the pick plays ($(session_state))"; else save_applog "$ph-pick"; fail "$ph: the pick did not play ($(session_state))"; fi
    else save_applog "$ph-pick"; fail "$ph: no track queued after the fan-out"; fi
    local bad; bad=$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -cE '\[dj\] (random-songs HTTP|.*400|.*dropped from this session|.*sits this pick out)')
    [ "$bad" -eq 0 ] && pass "$ph: no server dropped, no HTTP error during the pick" || { log "$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -E '\[dj\]' | tail -8)"; fail "$ph: $bad drop/error line(s) during the pick"; }
  else
    save_applog "$ph-pick"; log "$(applog | grep -E '\[dj\]|\[autodj\]' | tail -12)"; fail "$ph: no cross-server pick within 90s of the last track"
  fi
  shot "$ph-after-pick"
}

# ── phase 1: federated (parent on the phone, peer through it) ──────────────
plant rig-b "$(server_json rig-b "http://$HOST:$PB" "$TB" http "")"
for i in $(seq 1 90); do
  cfg_read servers.json | python3 -c "import sys,json; sys.exit(0 if any(s.get('federationParent')=='rig-b' for s in json.load(sys.stdin)) else 1)" && break; sleep 1
done
[ "$i" -lt 90 ] && pass "phase 1: peer reconciled under rig-b in ${i}s" || { save_applog p1-launch; fail "phase 1: no peer entry after 90s"; }
sleep 3  # the peer's own capability refresh (version + discovery flag) lands right after the reconcile
play_album p1; N=$TRACKS
[ "${N:-0}" -gt 0 ] && expect_pick "phase 1" "$N" rig-b peer-rig-peer-a
media_key pause; sleep 1; save_applog phase1

# ── phase 1b: the DJ hosted ON the peer (Scope 1) ──────────────────────────
# servers.json stays as the reconcile left it (the peer entry included — the
# launch restore resolves enabledServer against the list as loaded); only
# auto_dj.json changes: armed on the peer, the fan-out off, so this is the
# single-server path — a filepath seed the peer resolves itself, the pick
# streamed through the proxy or the peer's own tunnel.
python3 - "$RIG/auto_dj.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d.update(enabledServer='peer-rig-peer-a', multiServerEnabled=False); json.dump(d, open(p,'w'))
PY
app_stop; cfg_write auto_dj.json "$RIG/auto_dj.json"; logcat_clear; wake; app_start
wait_for_log '\[app\] default server ready' 30 || fail "phase 1b: default never published"
wait_for_log '\[autodj\] restored on peer-rig-peer-a' 15 && pass "phase 1b: DJ restored armed on the peer" || fail "phase 1b: DJ not restored on the peer"
N=$(cfg_read servers.json | python3 -c "import sys,json; print(len(json.load(sys.stdin)))"); PEER_Y=$((222 + 144 * (N - 1)))
tap $PICKER; sleep 1.5; shot p1b-picker; tap 639 $PEER_Y; sleep 3
wait_for_log '\[srv\] switched to peer-rig-peer-a' 5 && pass "phase 1b: peer selected from the picker" || fail "phase 1b: no switch to the peer"
tap $PEER_ALBUMS; sleep 4; shot p1b-albums; tap $ALBUM1; sleep 3; tap $TRACK1; sleep 6
n=$(applog | grep -oE '\[queue\] add [0-9]+ tracks' | tail -1 | grep -oE '[0-9]+' | head -1)
if [ -n "$n" ] && ensure_playing 15; then pass "phase 1b: peer album queued ($n tracks) and playing ($(session_state))"; else save_applog p1b-play; fail "phase 1b: peer album did not play ($(session_state))"; fi
if [ -n "$n" ]; then
  T=$(now_ts); for i in $(seq 2 "$n"); do adbx shell input keyevent 87; sleep 1.5; done
  if wait_for_log_after "$T" '\[queue\] add: ' 60; then
    srv=""
    for i in $(seq 1 10); do
      srv=$(cfg_read queue.json | python3 -c "
import sys,json
d=json.load(sys.stdin); it=(d.get('items') or [])[-1]; ex=it.get('extras') or {}
print(ex.get('server'), ex.get('djPick'), ex.get('djSonic'))" 2>/dev/null)
      case "$srv" in *" True True") break;; esac; sleep 1
    done
    [ "$srv" = "peer-rig-peer-a True True" ] && pass "phase 1b: the peer-hosted DJ queued a sonic pick from the peer's library (djPick + djSonic)" || fail "phase 1b: queued pick reads '$srv'"
    T2=$(now_ts); adbx shell input keyevent 87; sleep 8
    if wait_for_log_after "$T2" '\[play\] track [0-9]+/[0-9]+' 10 && is_playing; then pass "phase 1b: the peer's pick plays ($(session_state))"; else save_applog p1b-pick; fail "phase 1b: the pick did not play ($(session_state))"; fi
    bad=$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -cE '\[dj\] (random-songs HTTP|refused)|Track not found|multi-server:')
    [ "$bad" -eq 0 ] && pass "phase 1b: no HTTP error, no refusal, no fan-out during the peer-hosted pick" || { log "$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -E '\[dj\]' | tail -6)"; fail "phase 1b: $bad unexpected line(s) during the pick"; }
  else save_applog p1b-pick; log "$(applog | grep -E '\[dj\]|\[autodj\]' | tail -8)"; fail "phase 1b: no pick within 60s of the last track"; fi
fi
media_key pause; sleep 1; save_applog phase1b

# ── phase 2: own servers (the pairing removed; A planted directly) ─────────
curl -s -o /dev/null -X DELETE "http://127.0.0.1:$PB/api/v1/admin/federation/peers/$PEER_ID" -H "x-access-token: $TB"
plant rig-b "$(server_json rig-b "http://$HOST:$PB" "$TB" http "")" "$(server_json rig-a "http://$HOST:$PA" "$TA" http "")"
sleep 6  # both capability refreshes
play_album p2; N=$TRACKS
[ "${N:-0}" -gt 0 ] && expect_pick "phase 2" "$N" rig-b rig-a
media_key pause; sleep 1; save_applog phase2

# ── phase 3: Quick Connect fan-out (B a tunnel server, never browsed/queued) ─
curl -s -o /dev/null -X POST "http://127.0.0.1:$PB/api/v1/admin/iroh" -H "$J" -H "x-access-token: $TB" -d '{"enabled":true}'; sleep "${SMOKE_RIG_QC_WARMUP:-0}"
CODE=$(curl -s "http://127.0.0.1:$PB/api/v1/admin/iroh" -H "x-access-token: $TB" | python3 -c "import sys,json; print(json.load(sys.stdin).get('qr') or '')")
if [ -z "$CODE" ]; then fail "phase 3: no pairing code from B"; else
  plant rig-a "$(server_json rig-a "http://$HOST:$PA" "$TA" http "")" "$(server_json iroh-rig-b "iroh://rig-b" "$TB" iroh "$CODE")"
  # Tunnel-follows-the-DJ: B is neither browsed nor queued, only a fan-out
  # candidate of the armed session — its tunnel must come up on its own.
  # The first dials to a just-enabled Quick Connect can stall 13s each (mStream#940).
  if wait_for_log '\[iroh\] tunnel up .*for=iroh-rig-b' 150; then
    pass "phase 3: B's tunnel dialed for the armed session without being browsed or queued ($(applog | grep -oE 'tunnel up .*for=iroh-rig-b' | head -1 | grep -oE 'path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\)'))"
    applog | grep -q '\[srv\] switched to iroh-rig-b' && fail "phase 3: the app switched to B (the dial should not need that)" || pass "phase 3: B never selected, still dialed"
    applog | grep -qE 'ensure.*dj-(restore|fanout)|for=iroh-rig-b.*dj-(restore|fanout)' && log "reason seen: $(applog | grep -oE '[a-z-]*dj-(restore|fanout)[a-z-]*' | head -1)"
  else save_applog p3-launch; fail "phase 3: B's tunnel did not come up within 150s of the launch"; fi
  play_album p3; N=$TRACKS
  [ "${N:-0}" -gt 0 ] && expect_pick "phase 3" "$N" rig-a iroh-rig-b

  # ── phase 4: the DJ switched off releases the fan-out tunnel ─────────────
  # The pill toggles the DJ off when it is armed on the browsed server (rig-a
  # here). B is neither browsed nor queued, so the session was its only
  # reason to hold a tunnel: the manager reconciles at once on the DJ-off
  # path (no grace) and must not dial it again.
  if cfg_read queue.json | python3 -c "
import sys,json
d=json.load(sys.stdin); sys.exit(0 if any(((it.get('extras') or {}).get('server'))=='iroh-rig-b' for it in (d.get('items') or [])) else 1)" 2>/dev/null; then
    skip "phase 4: the pick came from B, whose queued track keeps its tunnel — the DJ-off release is not observable this run"
  else
    T=$(now_ts); tap $DJ_PILL; sleep 2; shot p4-dj-off
    if wait_for_log_after "$T" 'tunnel stopped .*for=iroh-rig-b' 20; then
      LINE=$(applog | grep -E 'tunnel stopped .*for=iroh-rig-b' | tail -1 | sed 's/^[0-9:.]* //')
      case "$LINE" in *no-target/dj-off*) pass "phase 4: B's tunnel released when the DJ was switched off — $LINE";; *) fail "phase 4: B's tunnel stopped for another reason: $LINE";; esac
      sleep 15; UPS=$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -cE 'tunnel up .*for=iroh-rig-b')
      [ "$UPS" -eq 0 ] && pass "phase 4: B not re-dialed in the 35s after the switch-off" || fail "phase 4: B re-dialed $UPS time(s) after the switch-off"
    else save_applog p4-off; log "$(applog | awk -v s="$T" '{ if (substr($1,1,12) >= s) print }' | grep -E '\[dj\]|\[autodj\]|\[iroh\]' | tail -6)"; fail "phase 4: B's tunnel still up 20s after the DJ was switched off"; fi
  fi
  media_key pause; sleep 1; save_applog phase3
fi
summary
