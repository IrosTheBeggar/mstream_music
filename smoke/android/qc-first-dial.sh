#!/usr/bin/env bash
# The first-dial stall (mStream#940): N fresh Quick Connect servers in a row,
# each handed to the phone the moment its pairing code exists; measures how
# many dials stall in the handshake before the tunnel comes up, and on which
# path it finally lands. Saves each iteration's server log (milestone lines
# from the instrumented server, `MSTREAM_IROH_TRACE=1`) and app log.
#   SMOKE_QC_ITER        iterations (default 8)
#   SMOKE_RIG_QC_WARMUP  seconds between enabling Quick Connect and the dial (default 0)
#   SMOKE_MSTREAM_SRC    server checkout with node_modules (default ~/code/mStream)
#   SMOKE_QC_MUSIC       music folder (default: an empty scratch folder — no scan work)
#   SMOKE_QC_REUSE_SERVER=1  one server for all iterations (only the phone's endpoint is fresh each time)
set -u
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
SRC="${SMOKE_MSTREAM_SRC:-$HOME/code/mStream}"; ITER=${SMOKE_QC_ITER:-8}; WARMUP=${SMOKE_RIG_QC_WARMUP:-0}
PORT=3121; J='Content-Type: application/json'; RIG="$OUT/rig"; mkdir -p "$RIG"
MUSIC="${SMOKE_QC_MUSIC:-$RIG/empty-music}"; mkdir -p "$MUSIC"
[ -f "$SRC/cli-boot-wrapper.js" ] && [ -d "$SRC/node_modules" ] || { echo "no server checkout with node_modules at $SRC"; exit 2; }
export NODE_ENV=test MSTREAM_TEST_BAKED_SEEDS='[]' MSTREAM_SIDECAR_BASE=http://127.0.0.1:9 MSTREAM_PLAYER_BASE=http://127.0.0.1:9 MSTREAM_IROH_TRACE=1
NODE=""; cleanup() { [ -n "$NODE" ] && kill $NODE 2>/dev/null; cfg_restore; }; trap cleanup EXIT
STALLS_TOTAL=0; BAD=0; declare -a ROWS
REUSE=${SMOKE_QC_REUSE_SERVER:-0}
for i in $(seq 1 "$ITER"); do
  if [ "$REUSE" = 1 ] && [ -n "$NODE" ]; then
    # same server, same code: only the phone's endpoint is new
    T_UP=$(date +%s.%N); sleep "$WARMUP"
    ONLINE=$(curl -s "http://127.0.0.1:$PORT/api/v1/admin/iroh" -H "x-access-token: $TOK" | python3 -c "import sys,json; d=json.load(sys.stdin); print('online' if d.get('online') else 'NOT-online')")
    app_stop; logcat_clear; wake; app_start; T0=$(date +%s.%N)
    wait_for_log 'tunnel up .*for=iroh-qc-test' 200; UP=$?
    T1=$(date +%s.%N); ELAPSED=$(python3 -c "print(round($T1-$T0,1))"); ENABLE_AGE=$(python3 -c "print(round($T0-$T_EN,1))")
    STALLS=$(count_log "tunnel start failed .*handshake stalled.*for=iroh-qc-test"); OTHER=$(count_log "tunnel start failed .*for=iroh-qc-test")
    PATH_=$(applog | grep -oE "tunnel up port=[0-9]+ path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\) for=iroh-qc-test" | head -1 | grep -oE 'path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\)')
    media_key pause 2>/dev/null; app_stop; save_applog "app-$i"
    if [ "$UP" = 0 ]; then ROW="iter $i (same server): stalls=$STALLS (other fails $((OTHER-STALLS))) up after ${ELAPSED}s, $PATH_, endpoint $ONLINE, server age ${ENABLE_AGE}s"
    else ROW="iter $i (same server): NO TUNNEL in 200s, stalls=$STALLS, endpoint $ONLINE, server age ${ENABLE_AGE}s"; fi
    log "$ROW"; ROWS+=("$ROW"); STALLS_TOTAL=$((STALLS_TOTAL+STALLS)); [ "$STALLS" -gt 0 ] && BAD=$((BAD+1))
    continue
  fi
  D="$RIG/s$i"; mkdir -p "$D"
  python3 - "$D" "$PORT" "$MUSIC" <<'PY'
import json,os,sys
d,port,root=sys.argv[1:]
st={k: os.path.join(d,v) for k,v in dict(albumArtDirectory='image-cache', dbDirectory='db', logsDirectory='logs', waveformCacheDirectory='waveform-cache').items()}
for p in st.values(): os.makedirs(p, exist_ok=True)
json.dump({"port":int(port),"address":"0.0.0.0","ui":"default","folders":{"m":{"root":root}},"storage":st,
  "scanOptions":{"autoAlbumArt":False,"collectDiscoveryData":False,"analyzeBpm":False},
  "discoveryP2p":{"seedListUrl":"http://127.0.0.1:9/discovery-seeds.json","useCommunitySeeds":False}},
  open(os.path.join(d,'config.json'),'w'), indent=2)
PY
  ( cd "$SRC" && exec node cli-boot-wrapper.js -j "$D/config.json" > "$RIG/s$i.log" 2>&1 ) & NODE=$!
  for t in $(seq 1 30); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/api/)" = 200 ] && break; sleep 1; done
  curl -s -o /dev/null -X PUT "http://127.0.0.1:$PORT/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["m"],"admin":true}'
  TOK=$(curl -s -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
  T_EN=$(date +%s.%N); curl -s -o /dev/null -X POST "http://127.0.0.1:$PORT/api/v1/admin/iroh" -H "$J" -H "x-access-token: $TOK" -d '{"enabled":true}'
  T_UP=$(date +%s.%N); sleep "$WARMUP"
  CODE=$(curl -s "http://127.0.0.1:$PORT/api/v1/admin/iroh" -H "x-access-token: $TOK" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('qr') or '')")
  ONLINE=$(curl -s "http://127.0.0.1:$PORT/api/v1/admin/iroh" -H "x-access-token: $TOK" | python3 -c "import sys,json; d=json.load(sys.stdin); print('online' if d.get('online') else 'NOT-online')")
  [ -n "$CODE" ] || { fail "iter $i: no pairing code"; kill $NODE; NODE=""; continue; }
  python3 - "$CFG_BACKUP/servers.json" "$RIG/servers.json" "$CODE" <<'PY'
import json,sys
src,dst,code=sys.argv[1:]
L=json.load(open(src))
s={"url":"iroh://qc-test","jwt":"","username":"rig","password":"rigpw","localname":"iroh-qc-test","autoDJPaths":{},"autoDJminRating":None,"autoDJGenreEnabled":False,"autoDJGenreMode":"whitelist","autoDJGenres":[],"playlists":[],"allowSelfSigned":False,"storageMode":"appLocal","storageBasePath":None,"transcodeAvailable":None,"transcodeDefaultCodec":None,"transcodeDefaultBitrate":None,"discoveryAvailable":None,"federationDiscoveryAvailable":None,"discoveryPathAvailable":None,"connectionType":"iroh","irohPairingCode":code,"serverVersion":None,"versionCheckedAt":None}
json.dump([s]+[x for x in L if x.get('localname')!='iroh-qc-test'], open(dst,'w'))
PY
  app_stop; cfg_write servers.json "$RIG/servers.json"; logcat_clear; wake; app_start; T0=$(date +%s.%N)
  wait_for_log 'tunnel up .*for=iroh-qc-test' 200; UP=$?
  T1=$(date +%s.%N); ELAPSED=$(python3 -c "print(round($T1-$T0,1))"); ENABLE_AGE=$(python3 -c "print(round($T0-$T_UP,1))")
  STALLS=$(count_log "tunnel start failed .*handshake stalled.*for=iroh-qc-test"); OTHER=$(count_log "tunnel start failed .*for=iroh-qc-test")
  PATH_=$(applog | grep -oE "tunnel up port=[0-9]+ path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\) for=iroh-qc-test" | head -1 | grep -oE 'path=[a-z]+ in [0-9]+ms \([a-z#0-9-]+\)')
  media_key pause 2>/dev/null; app_stop; save_applog "app-$i"
  if [ "$UP" = 0 ]; then ROW="iter $i: stalls=$STALLS (other fails $((OTHER-STALLS))) up after ${ELAPSED}s, $PATH_, endpoint $ONLINE, dial ${ENABLE_AGE}s after enable"
  else ROW="iter $i: NO TUNNEL in 200s, stalls=$STALLS, endpoint $ONLINE, dial ${ENABLE_AGE}s after enable"; fi
  log "$ROW"; ROWS+=("$ROW"); STALLS_TOTAL=$((STALLS_TOTAL+STALLS)); [ "$STALLS" -gt 0 ] && BAD=$((BAD+1))
  echo "== server milestones (iter $i) ==" >> "$OUT/milestones.log"; grep -E "\[iroh\]" "$RIG/s$i.log" | sed -E 's/\x1b\[[0-9;]*m//g' >> "$OUT/milestones.log"
  if [ "$REUSE" = 1 ]; then continue; fi
  kill $NODE 2>/dev/null; wait $NODE 2>/dev/null; NODE=""; sleep 2
done
log "iterations with a stall: $BAD/$ITER, stalls total: $STALLS_TOTAL, warm-up ${WARMUP}s"; [ "$BAD" -eq 0 ] && pass "no first-dial stall in $ITER fresh endpoints" || fail "$BAD/$ITER fresh endpoints stalled the first dial ($STALLS_TOTAL stalls)"
summary
