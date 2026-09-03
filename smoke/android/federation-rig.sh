#!/usr/bin/env bash
# Federation rig: two local mStream servers paired over the federation
# endpoint (peer A grants a library to parent B), parent B planted on the phone,
# and A browsed, played and downloaded THROUGH B's proxies — reached over plain
# HTTP on the LAN, or (SMOKE_RIG_IROH=1) over B's Quick Connect tunnel, so the
# peer rides the parent's loopback tunnel and the tunnel must survive a switch
# to a standard server while a peer track plays (the transport-aware tunnel
# target + queue listener, PR #129).
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
set -u
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
SRC="${SMOKE_MSTREAM_SRC:-$HOME/code/mStream}"; MUSIC="${SMOKE_RIG_MUSIC:-$HOME/code/mstream-demo-music}"
HOST="${SMOKE_RIG_HOST:-$(ipconfig getifaddr en0)}"; IROH="${SMOKE_RIG_IROH:-0}"
PA=3101; PB=3102; RIG="$OUT/rig"; mkdir -p "$RIG"; J='Content-Type: application/json'
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

# ── the parent on the phone ────────────────────────────────────────────────
if [ "$IROH" = 1 ]; then
  curl -s -o /dev/null -X POST "http://127.0.0.1:$PB/api/v1/admin/iroh" -H "$J" -H "x-access-token: $TB" -d '{"enabled":true}'; sleep 3
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
for i in $(seq 1 30); do
  cfg_read servers.json | python3 -c "import sys,json; sys.exit(0 if any(s.get('federationParent')=='$PARENT' for s in json.load(sys.stdin)) else 1)" && break; sleep 1
done
[ "$i" -lt 30 ] && pass "peer reconciled under $PARENT in ${i}s" || { save_applog rig-launch; fail "no peer entry after 30s"; summary; exit 1; }
N=$(cfg_read servers.json | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
PEER_Y=$((222 + 144 * (N - 1))) # picker rows: 222, 366, 510, … — the peer is listed last
tap $PICKER; sleep 1.5; shot picker; tap 639 $PEER_Y; sleep 3
wait_for_log '\[srv\] switched to peer-rig-peer-a' 5 && pass "peer selected from the picker" || fail "no switch to the peer"
shot peer-nav
tap $ALBUMS_ROW; sleep 4; shot peer-albums; tap $ALBUM1; sleep 3; tap $TRACK1; sleep 6
if wait_for_log '\[queue\] add [0-9]+ tracks' 5 && is_playing; then pass "peer album queued and playing through the stream proxy ($(session_state))"; else save_applog rig-play; fail "peer track did not play ($(session_state))"; fi
shot peer-playing
adbx shell "run-as $PKG test -d app_flutter/media/peer-rig-peer-a" && pass "download folder created for the peer" || fail "no media/peer-rig-peer-a folder"
if [ "$IROH" = 1 ]; then
  [ "$(count_log 'tunnel stopped')" -eq 0 ] && pass "browsing the peer kept the parent's tunnel" || fail "the parent's tunnel was stopped while the peer was browsed"
  # switch to the first standard server (row 2) while the peer track plays
  T=$(now_ts); tap $PICKER; sleep 1.5; tap 782 366; sleep 5
  wait_for_log_after "$T" '\[srv\] switched to ' 5 || fail "no switch away from the peer"
  if is_playing && [ "$(count_log 'tunnel stopped')" -eq 0 ]; then pass "tunnel kept for the queued peer track after switching to a standard server"; else fail "tunnel or playback lost after the switch ($(session_state))"; fi
  # Phase 4: relaunch with the peer track queued. The parent's tunnel comes up on
  # a FRESH port, so the restored peer URLs (stream through the parent's proxy,
  # art through its art proxy) must be re-derived against it — or the track
  # plays from a dead loopback port.
  PORT1=$(applog | grep -oE 'tunnel up port=[0-9]+' | head -1 | grep -oE '[0-9]+$')
  media_key pause; sleep 1; app_stop; logcat_clear; wake; app_start
  wait_for_log '\[iroh\] tunnel up' 45 || fail "no tunnel after the relaunch"
  PORT2=$(applog | grep -oE 'tunnel up port=[0-9]+' | head -1 | grep -oE '[0-9]+$')
  if wait_for_log '\[play\] track [0-9]+/[0-9]+' 30; then
    sleep 3; ensure_playing 15 && pass "restored peer track plays after a relaunch (port $PORT1 → $PORT2)" || { save_applog rig-relaunch; fail "restored peer track did not play on the fresh port ($(session_state))"; }
  else save_applog rig-relaunch; fail "queue did not restore after the relaunch"; fi
fi
media_key pause; sleep 1
save_applog federation-rig
summary
