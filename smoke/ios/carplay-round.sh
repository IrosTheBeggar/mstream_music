#!/usr/bin/env bash
# CarPlay round on the iOS Simulator, driven through the app's debug hook
# (`ext.mstream.carplay`, debug builds only). The Simulator's CarPlay window
# takes no synthetic input, so ONE thing is manual: when prompted, click the
# mStream icon in the "… – CarPlay" window. Everything after that is scripted:
# root, Albums → album → track → Now Playing, Queue + skip, the three Now
# Playing buttons, the artist button, a Siri dry-run, the 5-deep guard.
#   SMOKE_SIM_UDID   booted simulator (default: the first booted iPhone)
#   SMOKE_APP        Runner.app (default build/ios/iphonesimulator/Runner.app; SMOKE_BUILD=1 builds it)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; OUT="${SMOKE_OUT:-$ROOT/smoke/out/$(date +%Y%m%d-%H%M%S)-carplay-round}"; mkdir -p "$OUT"
PASS=0; FAIL=0
log(){ echo "$(date '+%H:%M:%S') $*" | tee -a "$OUT/run.log"; }; pass(){ PASS=$((PASS+1)); log "PASS  $*"; }; fail(){ FAIL=$((FAIL+1)); log "FAIL  $*"; }
UDID="${SMOKE_SIM_UDID:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)}"
[ -n "$UDID" ] || { echo "no booted simulator"; exit 2; }
APP="${SMOKE_APP:-$ROOT/build/ios/iphonesimulator/Runner.app}"
if [ "${SMOKE_BUILD:-0}" = 1 ]; then (cd "$ROOT" && flutter build ios --simulator --debug | tail -1); fi
[ -d "$APP" ] || { echo "no $APP (set SMOKE_BUILD=1)"; exit 2; }
PORT=48123; VM="http://127.0.0.1:$PORT/"
xcrun simctl terminate "$UDID" mstream.music 2>/dev/null; xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" mstream.music --vm-service-port=$PORT --disable-service-auth-codes >/dev/null; sleep 10
ISO=$(curl -s --max-time 5 "${VM}getVM" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['isolates'][0]['id'])")
ISOQ=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$ISO")
cpx(){ local extra=""; if [ -n "${2:-}" ]; then case "$1" in siri) extra="&query=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$2")";; *) extra="&index=$2";; esac; fi
  curl -s --max-time 40 "${VM}ext.mstream.carplay?isolateId=${ISOQ}&action=$1${extra}" | python3 -c "import sys,json
raw=sys.stdin.read()
try:
    d=json.loads(raw); r=d.get('result', d); print(json.dumps(r if isinstance(r,(dict,list)) else d, ensure_ascii=False))
except Exception: print('{}')"; }
field(){ python3 -c "import sys,json; d=json.loads(sys.argv[1]); v=d
for k in sys.argv[2].split('.'): v=v.get(k) if isinstance(v,dict) else None
print('' if v is None else v)" "$1" "$2"; }
shot(){ xcrun simctl io "$UDID" screenshot --display external "$OUT/$1.png" >/dev/null 2>&1; }
# open the CarPlay display if the Simulator GUI is up
osascript -e 'tell application "System Events" to tell process "Simulator" to click menu item "CarPlay" of menu "External Displays" of menu item "External Displays" of menu "I/O" of menu bar 1' >/dev/null 2>&1 &
sleep 3; kill %1 2>/dev/null
echo; echo ">>> Click the mStream icon in the Simulator's CarPlay window now (waiting up to 3 min)"; echo
i=0; while [ $i -lt 180 ]; do [ "$(field "$(cpx state)" connected)" = "True" ] && break; sleep 2; i=$((i+2)); done
[ "$(field "$(cpx state)" connected)" = "True" ] || { fail "CarPlay scene never connected"; log "== $PASS pass, $FAIL fail"; exit 1; }
S=$(cpx state); echo "$S" | grep -q '"Shuffle All"' && pass "root list" || fail "root list: $S"; shot root
cpx tap 3 >/dev/null; sleep 3; S=$(cpx state); [ "$(field "$S" title)" = "Albums" ] && pass "Albums ($(echo "$S" | grep -o '"items": \[[^]]*' | tr -cd ',' | wc -c | tr -d ' ') rows)" || fail "Albums: $S"; shot albums
cpx tap 0 >/dev/null; sleep 3; S=$(cpx state); [ "$(field "$S" depth)" = "3" ] && pass "album opened: $(field "$S" title)" || fail "album: $S"
cpx tap 0 >/dev/null; sleep 6; S=$(cpx state); [ "$(field "$S" top)" = "CPNowPlayingTemplate" ] && pass "track played → Now Playing" || fail "Now Playing: $S"; shot nowplaying
cpx upnext >/dev/null; sleep 3; S=$(cpx state); [ "$(field "$S" title)" = "Queue" ] && pass "Up Next → Queue" || fail "Queue: $S"; shot queue
cpx tap 1 >/dev/null; sleep 3; S=$(cpx state); [ "$(field "$S" top)" = "CPNowPlayingTemplate" ] && pass "queue row → skip, back on Now Playing" || fail "after skip: $S"
cpx button 0 >/dev/null; sleep 2; [ "$(field "$(cpx state)" modes.shuffle)" = "True" ] && pass "shuffle on" || fail "shuffle"
cpx button 1 >/dev/null; sleep 2; [ "$(field "$(cpx state)" modes.repeat)" = "all" ] && pass "repeat → all" || fail "repeat"
cpx button 1 >/dev/null; sleep 2; cpx button 1 >/dev/null; sleep 2; cpx button 0 >/dev/null; sleep 2
dj0=$(field "$(cpx state)" modes.autoDJ); cpx button 2 >/dev/null; sleep 3; dj1=$(field "$(cpx state)" modes.autoDJ); [ "$dj0" != "$dj1" ] && pass "Auto DJ toggled ($dj0 → $dj1)" || fail "Auto DJ did not toggle"; cpx button 2 >/dev/null; sleep 2; shot buttons
cpx artist >/dev/null; sleep 4; S=$(cpx state); [ "$(field "$S" depth)" = "5" ] && pass "artist button → $(field "$S" title)" || fail "artist: $S"
R=$(cpx siri "Color Out"); [ "$(field "$R" response)" = "4" ] && pass "Siri dry-run: $(echo "$R" | grep -o '"candidates": \[[^]]*\]' | cut -c1-80)" || fail "Siri: $R"
sleep 4; cpx upnext >/dev/null; sleep 3; S=$(cpx state); [ "$(field "$S" depth)" = "5" ] && [ "$(field "$S" title)" = "Queue" ] && pass "depth guard held the stack at 5" || fail "depth guard: $S"
xcrun simctl spawn "$UDID" log show --last 5m --predicate 'process == "Runner"' --style compact 2>/dev/null | grep -E "\[carplay\]|\[siri\]|flutter: \[play\]" | sed 's/^.*Runner\[[0-9]*:[0-9a-f]*\] //; s/(Flutter) flutter: //; s/(Foundation) //' > "$OUT/carplay.log"
log "== carplay-round: $PASS pass, $FAIL fail — artifacts in $OUT"; [ "$FAIL" -eq 0 ]
