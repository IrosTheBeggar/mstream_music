#!/usr/bin/env bash
# Screen-off playback soak (Samsung app-sleep, Doze): play, screen off, poll
# every minute — the process must survive and the session stay PLAYING.
#   SMOKE_SOAK_MIN   minutes (default 120)
source "$(dirname "$0")/../lib.sh"; pick_device
MIN=${SMOKE_SOAK_MIN:-120}
trap 'wake' EXIT
[ -n "$(app_pid)" ] || { wake; app_start; sleep 12; }
logcat_clear
ensure_playing 20 || { save_applog soak-start; fail "did not start playing ($(session_state))"; summary; exit 1; }
PID0=$(app_pid); key KEYCODE_SLEEP; log "screen off, soaking ${MIN} min (pid $PID0)"
i=0; bad=0
while [ "$i" -lt "$MIN" ]; do
  sleep 60; i=$((i+1))
  st=$(session_state); pid=$(app_pid)
  log "  +${i}m pid=${pid:-dead} $st"
  if [ "$pid" != "$PID0" ] || ! echo "$st" | grep -q PLAYING; then bad=$((bad+1)); fi
done
[ "$bad" -eq 0 ] && pass "survived ${MIN} min screen-off, PLAYING at every poll" || fail "$bad bad poll(s) (restart or not playing)"
n=$(count_log '\[play\] pause'); [ "$n" -eq 0 ] && pass "no unexpected pause" || fail "$n pause line(s) during the soak"
save_applog soak; summary
