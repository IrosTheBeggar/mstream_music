#!/usr/bin/env bash
# The car-off race: the head unit's late PAUSE arrives after the audio link
# dropped. Stand-ins: `svc bluetooth disable` (the drop) and a PAUSE media key
# through the system dispatcher (the AVRCP command). Needs a Bluetooth headset
# connected (A2DP active) — pair one and connect it first.
#   SMOKE_BT_ROW_XY   first "Paired devices" row in Settings › Bluetooth, used to reconnect (default "343 998")
source "$(dirname "$0")/../lib.sh"; pick_device
BTROW=${SMOKE_BT_ROW_XY:-"343 998"}
reconnect_headset() {
  bluetooth enable; sleep 8
  adbx shell am start -a android.settings.BLUETOOTH_SETTINGS >/dev/null 2>&1; sleep 4; tap $BTROW; sleep 10; key KEYCODE_BACK
  bt_connected && log "headset reconnected ($(a2dp_route))" || log "headset NOT reconnected — reconnect it by hand"
}
trap 'reconnect_headset' EXIT
bt_connected || { skip "no Bluetooth headset connected"; trap - EXIT; summary; exit; }
app_stop; logcat_clear; wake; app_start; sleep 15
ensure_playing 20 || { save_applog bt-launch; log "session: $(session_state) route: $(a2dp_route)"; fail "did not start playing (see $OUT/bt-launch.log)"; summary; exit 1; }
sleep 5; log "route: $(a2dp_route)"
log "== drop"; bluetooth disable
wait_for_log 'output disconnected — pausing' 15 && pass "drop paused the app" || fail "no becoming-noisy pause"
sleep 6; media_key pause; sleep 3
if wait_for_log 'media button toggle ignored' 3; then pass "late PAUSE ignored"; else fail "late PAUSE not ignored"; fi
n=$(applog | awk '/output disconnected/{f=1} f && /\[play\] play$/' | wc -l | tr -d ' ')
[ "$n" -eq 0 ] && pass "no play after the drop (state $(session_state))" || fail "playback resumed after the drop"
save_applog bt
summary
