#!/usr/bin/env bash
# Headless resume: the app's process is killed (the way the OS reclaims it —
# NOT `am force-stop`, which puts an app in Android's stopped state where no
# media key may start it), then a PLAY media key arrives (a headset button /
# the car). The service must boot without the UI, restore the saved queue,
# and play — with the Quick Connect tunnel dialed behind it.
source "$(dirname "$0")/../lib.sh"; pick_device
app_stop; logcat_clear; wake; app_start; sleep 15; ensure_playing 20 || log "(could not start playback before the kill)"; sleep 3; is_playing && media_key pause; sleep 2
key KEYCODE_HOME; sleep 2; PID=$(app_pid); adbx shell "run-as $PKG kill -9 $PID" 2>/dev/null; sleep 3
[ -z "$(app_pid)" ] && log "process $PID killed" || { fail "could not kill the process"; summary; exit 1; }
logcat_clear; log "== PLAY key with the app dead"; media_key play
if wait_for_log '\[app\] mStream ' 20; then pass "service booted headless"; else fail "no boot within 20s"; fi
if wait_for_log '\[play\] play' 30; then pass "playback started ($(session_state))"; else fail "no play within 30s"; fi
wait_for_log '\[play\] track ' 30 && pass "queue restored: $(applog | grep -oE '\[play\] track [0-9]+/[0-9]+: .*' | head -1)" || fail "no track line"
save_applog resumption
summary
