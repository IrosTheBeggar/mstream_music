#!/usr/bin/env bash
# Quick Connect dead-zone round on cellular (the drive): Wi-Fi → cellular
# hand-off, a 75s airplane-mode outage, the banner's Retry during a second
# outage, Wi-Fi return. Checks the reconnects happen IN PLACE (same port, no
# rebuild) and within a bounded time of service returning.
#   SMOKE_RETRY_XY   the banner's Retry button (default "948 516", Galaxy S25)
#   SMOKE_OUTAGE_S   outage length (default 75)
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
IROH=$(localname_of iroh); [ -n "$IROH" ] || { skip "needs a Quick Connect server"; summary; exit; }
RETRY=${SMOKE_RETRY_XY:-"948 516"}; OUTAGE=${SMOKE_OUTAGE_S:-75}
trap 'airplane disable; wifi enable; cfg_restore' EXIT
log "order: $(cfg_order iroh)"; cfg_dj "$IROH"
app_stop; logcat_clear; wake; app_start
wait_for_log '\[iroh\] tunnel up' 20 || { fail "no tunnel at launch"; summary; exit 1; }
PORT=$(applog | grep -oE 'tunnel up port=[0-9]+' | head -1 | grep -oE '[0-9]+$'); log "port $PORT"
# A PLAY key in the first seconds after a cold start is dropped (the session is not
# the media-button target yet); the other scripts settle 12-15s before theirs.
sleep 10; ensure_playing 20 || log "(not playing — continuing with the tunnel checks)"; sleep 5
log "== hand-off: wifi off"; HO=$(now_ts); wifi disable
wait_for_log_after "$HO" 'probe #[12] passed|reconnected: attempt' 45 && pass "hand-off: tunnel kept (probe passed)" || fail "hand-off: no probe pass within 45s"
log "== outage 1: airplane ${OUTAGE}s"; airplane enable; sleep "$OUTAGE"; BACK=$(now_ts); airplane disable
if wait_for_log_after "$BACK" 'reconnected: attempt' 90; then
  d=$(secs_between "$BACK" "$(ts_after "$BACK" 'reconnected: attempt')"); pass "outage 1: reconnected in place ${d}s after airplane off"
else fail "outage 1: no in-place reconnect within 90s"; fi
sleep 10
log "== outage 2: Retry tap while reconnecting"; O2=$(now_ts); airplane enable
wait_for_log_after "$O2" 'status connected → reconnecting' 75 || log "   (no reconnecting edge yet)"
sleep 5; shot banner; tap $RETRY; sleep 3
if wait_for_log 'kicking the tunnel in place \(retry-tap\)' 5; then pass "Retry kicked in place"; else fail "Retry did not kick (rebuild?)"; fi
sleep 20; BACK=$(now_ts); airplane disable
# A Retry kick that lands inside the dead zone cannot take until service returns; if the
# supervisor has not converged 45s after the kick, the post-kick watchdog rebuilds the
# tunnel on a fresh port (rotating the stream URLs) — the designed fallback, not a bug.
REC='reconnected: attempt|tunnel up .*\(rebuild/watchdog\)'
if wait_for_log_after "$BACK" "$REC" 90; then
  d=$(secs_between "$BACK" "$(ts_after "$BACK" "$REC")")
  if applog | awk -v s="$BACK" '{ if (substr($1,1,12) >= s) print }' | grep -q 'rebuild/watchdog'; then
    pass "outage 2: the post-kick watchdog rebuilt the tunnel ${d}s after airplane off (in place did not converge in 45s)"
  else pass "outage 2: reconnected in place ${d}s after airplane off"; fi
else fail "outage 2: neither an in-place reconnect nor the watchdog rebuild within 90s"; fi
log "== return home: wifi on"; HOME_TS=$(now_ts); wifi enable
# A connection that just moved from cellular to Wi-Fi may fail both probes; the in-place
# kick that follows is the recovery then. Report the time and the path it took.
after_home() { applog | awk -v s="$HOME_TS" '{ if (substr($1,1,12) >= s) print }'; }
if wait_for_log_after "$HOME_TS" 'probe #[12] passed|reconnected: attempt' 60; then
  d=$(secs_between "$HOME_TS" "$(ts_after "$HOME_TS" 'probe #[12] passed|reconnected: attempt')")
  how=$(after_home | grep -oE 'probe #[12] (passed|failed) \([a-z 0-9]+|kicking the tunnel|reconnected: attempt [0-9]+ in [0-9.]+s' | tr '\n' ';')
  pass "Wi-Fi return: tunnel serving ${d}s after wifi on [$how]"
else fail "Wi-Fi return: neither a probe pass nor a reconnect within 60s"; fi
log "player after the return: $(after_home | grep -E '\[play\]|rror' | sed 's/^[0-9:.]* //' | cut -c1-60 | tr '\n' ';')"
save_applog dead-zone
# After the launch dial, every tunnel must be an in-place reconnect (same port) or the
# post-kick watchdog's rebuild; stream URLs may only be rebuilt by that rebuild.
dials=$(applog | grep -E 'tunnel up port=' | tail -n +2 | grep -vcE '\(rebuild/watchdog\)' | tr -d ' ')
wd=$(count_log 'tunnel up .*\(rebuild/watchdog\)'); urls=$(count_log 'stream URLs rebuilt')
if [ "$dials" -eq 0 ]; then pass "no unexplained rebuild (${wd} watchdog rebuild(s))"; else fail "$dials tunnel dial(s) that were neither the launch nor the watchdog"; fi
if [ "$urls" -le "$wd" ]; then pass "stream URLs rebuilt only by the watchdog ($urls)"; else fail "stream URLs rebuilt ${urls}× with $wd watchdog rebuild(s)"; fi
summary
