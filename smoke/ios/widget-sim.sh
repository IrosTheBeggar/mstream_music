#!/usr/bin/env bash
# The home-screen widget on the iOS Simulator, as far as a script can see it:
# the extension is in the built app, the app writes its snapshot into the App
# Group container and reports the handshake with the extension's intents, a
# transport action through the same path the widget's buttons take reaches the
# handler and re-publishes. Placing the widget and tapping it needs the
# Simulator's home screen (the recipe), which `simctl` cannot drive.
#   SMOKE_SIM_UDID   booted simulator (default: the first booted iPhone)
#   SMOKE_APP        Runner.app (default build/ios/iphonesimulator/Runner.app; SMOKE_BUILD=1 builds it)
# The action round trip needs a track: it is skipped when the app restored
# no queue (see the recipe for seeding one from the emulator's rig queue).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; OUT="${SMOKE_OUT:-$ROOT/smoke/out/$(date +%Y%m%d-%H%M%S)-widget-sim}"; mkdir -p "$OUT"
PASS=0; FAIL=0; SKIP=0
log(){ echo "$(date '+%H:%M:%S') $*" | tee -a "$OUT/run.log"; }; pass(){ PASS=$((PASS+1)); log "PASS  $*"; }; fail(){ FAIL=$((FAIL+1)); log "FAIL  $*"; }; skip(){ SKIP=$((SKIP+1)); log "SKIP  $*"; }
UDID="${SMOKE_SIM_UDID:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)}"
[ -n "$UDID" ] || { echo "no booted simulator"; exit 2; }
APP="${SMOKE_APP:-$ROOT/build/ios/iphonesimulator/Runner.app}"
if [ "${SMOKE_BUILD:-0}" = 1 ]; then (cd "$ROOT" && flutter build ios --simulator --debug | tail -1); fi
[ -d "$APP" ] || { echo "no $APP (set SMOKE_BUILD=1)"; exit 2; }
# ── the bundle ──
APPEX="$APP/PlugIns/NowPlayingWidget.appex"
[ -f "$APPEX/NowPlayingWidget" ] && pass "widget extension embedded in Runner.app" || fail "no NowPlayingWidget.appex in PlugIns"
plutil -p "$APPEX/Info.plist" 2>/dev/null | grep -q "com.apple.widgetkit-extension" && pass "extension point is WidgetKit" || fail "extension point wrong or missing"
plutil -p "$APP/Info.plist" 2>/dev/null | grep -q '"mstream"' && pass "mstream:// URL scheme registered" || fail "no mstream URL scheme"
V1=$(plutil -p "$APP/Info.plist" | grep CFBundleShortVersionString); V2=$(plutil -p "$APPEX/Info.plist" | grep CFBundleShortVersionString)
[ "$V1" = "$V2" ] && pass "extension version matches the app's" || fail "version mismatch: app $V1 / extension $V2"
# ── the app, live ──
PORT=48126; VM="http://127.0.0.1:$PORT/"
xcrun simctl terminate "$UDID" mstream.music 2>/dev/null; xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" mstream.music --vm-service-port=$PORT --disable-service-auth-codes >/dev/null; sleep 12
ISO=$(curl -s --max-time 5 "${VM}getVM" | python3 -c "import sys,json; iso=json.load(sys.stdin)['result']['isolates']; print(([i for i in iso if i.get('name')=='main'] or iso)[0]['id'])" 2>/dev/null)
[ -n "$ISO" ] || { fail "VM service unreachable (debug build?)"; log "== widget-sim: $PASS pass, $FAIL fail, $SKIP skip"; exit 1; }
ISOQ=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$ISO")
wx(){ curl -s --max-time 20 "${VM}ext.mstream.widget?isolateId=${ISOQ}&action=$1" | python3 -c "import sys,json
try: d=json.load(sys.stdin); print(json.dumps(d.get('result', d)))
except Exception: print('{}')"; }
field(){ python3 -c "import sys,json; d=json.loads(sys.argv[1]); v=d
for k in sys.argv[2].split('.'): v=v.get(k) if isinstance(v,dict) else None
print('' if v is None else v)" "$1" "$2"; }
S=$(wx state)
[ "$(field "$S" result.native.container)" = "True" ] && pass "App Group container resolved" || fail "no App Group container: $S"
[ "$(field "$S" result.native.dartUp)" = "True" ] && pass "intent handshake done (Dart up)" || fail "handshake missing: $S"
[ -n "$(field "$S" result.native.snapshot.updatedAt)" ] && pass "snapshot written to the container" || fail "no snapshot in the container"
python3 -c "import sys,json; d=json.loads(sys.argv[1]); s=d['result']['native']['snapshot']; sys.exit(0 if 'artUrl' not in s else 1)" "$S" && pass "art URL (session token) kept out of the container" || fail "artUrl leaked into the container"
if [ "$(field "$S" result.native.snapshot.hasTrack)" = "True" ]; then
  T0=$(field "$S" result.native.snapshot.title)
  wx "act&name=play" >/dev/null; sleep 4; S=$(wx state)
  [ "$(field "$S" result.native.snapshot.playing)" = "True" ] && pass "play through the intent path → playing" || fail "play did not start: $(field "$S" result.native.snapshot.playing)"
  wx "act&name=pause" >/dev/null; sleep 3; S=$(wx state)
  [ "$(field "$S" result.native.snapshot.playing)" = "False" ] && pass "pause through the intent path → paused" || fail "pause did not take"
  wx "act&name=next" >/dev/null; sleep 4; S=$(wx state); T1=$(field "$S" result.native.snapshot.title)
  [ -n "$T1" ] && [ "$T1" != "$T0" ] && pass "next through the intent path: \"$T0\" → \"$T1\"" || fail "next did not change the track (\"$T0\" → \"$T1\")"
else
  skip "no track restored — seed a queue for the action round trip (recipe)"
fi
xcrun simctl spawn "$UDID" log show --last 3m --predicate 'process == "Runner"' --style compact 2>/dev/null | grep -E "\[widget\]|flutter: \[play\]" | sed 's/^.*Runner\[[0-9]*:[0-9a-f]*\] //; s/(Flutter) flutter: //; s/(Foundation) //' > "$OUT/widget.log"
xcrun simctl io "$UDID" screenshot "$OUT/phone.png" >/dev/null 2>&1
log "== widget-sim: $PASS pass, $FAIL fail, $SKIP skip — artifacts in $OUT"; [ "$FAIL" -eq 0 ]
