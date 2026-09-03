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
ensure_playing 20 || log "(not playing — continuing with the tunnel checks)"; sleep 5
log "== hand-off: wifi off"; HO=$(now_hms); wifi disable
wait_for_log_after "$HO" 'probe #[12] passed|reconnected: attempt' 45 && pass "hand-off: tunnel kept (probe passed)" || fail "hand-off: no probe pass within 45s"
log "== outage 1: airplane ${OUTAGE}s"; airplane enable; sleep "$OUTAGE"; BACK=$(now_hms); airplane disable
if wait_for_log_after "$BACK" 'reconnected: attempt' 90; then
  d=$(secs_between "$BACK" "$(ts_after "$BACK" 'reconnected: attempt')"); pass "outage 1: reconnected in place ${d}s after airplane off"
else fail "outage 1: no in-place reconnect within 90s"; fi
sleep 10
log "== outage 2: Retry tap while reconnecting"; O2=$(now_hms); airplane enable
wait_for_log_after "$O2" 'status connected → reconnecting' 75 || log "   (no reconnecting edge yet)"
sleep 5; shot banner; tap $RETRY; sleep 3
if wait_for_log 'kicking the tunnel in place \(retry-tap\)' 5; then pass "Retry kicked in place"; else fail "Retry did not kick (rebuild?)"; fi
sleep 20; BACK=$(now_hms); airplane disable
if wait_for_log_after "$BACK" 'reconnected: attempt' 90; then d=$(secs_between "$BACK" "$(ts_after "$BACK" 'reconnected: attempt')"); pass "outage 2: reconnected ${d}s after airplane off"; else fail "outage 2: no reconnect within 90s"; fi
log "== return home: wifi on"; HOME_TS=$(now_hms); wifi enable
# A migrating connection may fail both probes; the in-place kick that follows counts as recovery too.
wait_for_log_after "$HOME_TS" 'probe #[12] passed|reconnected: attempt' 60 && pass "Wi-Fi return: tunnel serving ($(ts_after "$HOME_TS" 'probe #[12] passed|reconnected: attempt'))" || fail "Wi-Fi return: neither a probe pass nor a reconnect within 60s"
save_applog dead-zone
ports=$(applog | grep -oE 'tunnel up port=[0-9]+' | sort -u | wc -l | tr -d ' ')
if [ "$ports" -le 1 ]; then pass "same port throughout"; else fail "$ports distinct ports (a rebuild happened)"; fi
if [ "$(count_log 'stream URLs rebuilt')" -eq 0 ]; then pass "no URL rebuild"; else fail "stream URLs rebuilt during the round"; fi
summary
