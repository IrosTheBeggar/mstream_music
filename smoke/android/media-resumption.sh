#!/usr/bin/env bash
# Headless resume: the app's process is killed (the way the OS reclaims it —
# NOT `am force-stop`, which puts an app in Android's stopped state where no
# media key may start it), then a PLAY media key arrives (a headset button /
# the car). The service must boot without the UI, restore the saved queue,
# and play — with the Quick Connect tunnel dialed behind it.
#
# The saved queue's server decides how hard this is: a standard server
# restores in a second or two; a Quick Connect queue dials the tunnel first,
# which can take longer than the ten seconds One UI gives a cached process
# before it freezes it (Galaxy S25, 2026-09-21). The play must therefore hold
# the service in the foreground for the wait — the "holding" line below — and
# the new process must never show up in the freezer's event log before it
# plays. Which case ran is reported from queue.json; to cover the Quick
# Connect one, queue tracks from that server before running.
source "$(dirname "$0")/../lib.sh"; pick_device
QSRV=$(cfg_read queue.json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin); it = d.get('items') or []
    print(', '.join(sorted({(x.get('extras') or {}).get('server', '?') for x in it})) + ' (' + str(len(it)) + ' tracks)')
except Exception: print('unknown')")
log "saved queue on: ${QSRV:-unknown}"
app_stop; logcat_clear; wake; app_start; sleep 15; ensure_playing 20 || log "(could not start playback before the kill)"; sleep 3; is_playing && media_key pause; sleep 2
key KEYCODE_HOME; sleep 2; PID=$(app_pid); adbx shell "run-as $PKG kill -9 $PID" 2>/dev/null; sleep 3
[ -z "$(app_pid)" ] && log "process $PID killed" || { fail "could not kill the process"; summary; exit 1; }
logcat_clear; log "== PLAY key with the app dead"; media_key play
if wait_for_log '\[app\] mStream ' 20; then pass "service booted headless"; else fail "no boot within 20s"; fi
NEWPID=$(app_pid)
if wait_for_log '\[play\] play' 30; then pass "play reached the handler"; else fail "no play within 30s"; fi
# The hold is only needed when the play beat the restore; a restore that had
# already settled (a fast standard server) needs none.
if wait_for_log '\[play\] holding the service in the foreground' 5; then pass "service held in the foreground for the restore"
elif [ -n "$(first_ts '\[play\] track ')" ] && [ "$(first_ts '\[play\] track ')" \< "$(first_ts '\[play\] play')" ]; then skip "restore settled before the play arrived — no hold needed"
else fail "play waited for the restore without holding the service in the foreground"; fi
wait_for_log '\[play\] track ' 40 && pass "queue restored: $(applog | grep -oE '\[play\] track [0-9]+/[0-9]+: .*' | head -1)" || fail "no track line within 40s"
wait_playing 20 && pass "playing ($(session_state))" || fail "not playing within 20s of the restore ($(session_state))"
# The freezer's own record: this process must not have been frozen on the way.
FROZE=$(adbx logcat -b events -d 2>/dev/null | grep -E "am_freeze.*\[$NEWPID," | head -1)
[ -z "$FROZE" ] && pass "process $NEWPID never frozen by the OS" || fail "process frozen before it played: $FROZE"
save_applog resumption
summary
