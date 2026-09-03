#!/usr/bin/env bash
# iOS Simulator launch + life-cycle: the app boots from the app-owned engine,
# the phone UI renders, and a background/foreground cycle reaches Dart
# (the manual scene registration). Also the headless check: with the app
# terminated, Dart must still boot when the CarPlay scene launches it — that
# part needs a click, so it lives in carplay-round.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; OUT="${SMOKE_OUT:-$ROOT/smoke/out/$(date +%Y%m%d-%H%M%S)-sim-launch}"; mkdir -p "$OUT"
PASS=0; FAIL=0; log(){ echo "$(date '+%H:%M:%S') $*" | tee -a "$OUT/run.log"; }; pass(){ PASS=$((PASS+1)); log "PASS  $*"; }; fail(){ FAIL=$((FAIL+1)); log "FAIL  $*"; }
UDID="${SMOKE_SIM_UDID:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)}"; [ -n "$UDID" ] || { echo "no booted simulator"; exit 2; }
APP="${SMOKE_APP:-$ROOT/build/ios/iphonesimulator/Runner.app}"; [ -d "$APP" ] || { echo "no $APP"; exit 2; }
applog(){ xcrun simctl spawn "$UDID" log show --start "$1" --predicate 'process == "Runner"' --style compact 2>/dev/null | grep -E "flutter: \[" | sed 's/^\(.\{19\}\).*flutter: /\1 /'; }
xcrun simctl terminate "$UDID" mstream.music 2>/dev/null; xcrun simctl install "$UDID" "$APP"
M=$(date '+%Y-%m-%d %H:%M:%S'); xcrun simctl launch "$UDID" mstream.music >/dev/null; sleep 15
L=$(applog "$M"); echo "$L" > "$OUT/launch.log"
echo "$L" | grep -q '\[app\] mStream ' && pass "Dart booted" || fail "no boot line"
echo "$L" | grep -q '\[app\] default server ready' && pass "default server published" || fail "default never published"
xcrun simctl io "$UDID" screenshot "$OUT/phone.png" >/dev/null 2>&1
M2=$(date '+%Y-%m-%d %H:%M:%S'); xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null; sleep 3; xcrun simctl launch "$UDID" mstream.music >/dev/null; sleep 6
applog "$M2" | grep -q 'network change (resume)' && pass "resume reached Dart after a background cycle" || fail "no resume event"
log "== sim-launch: $PASS pass, $FAIL fail — artifacts in $OUT"; [ "$FAIL" -eq 0 ]
