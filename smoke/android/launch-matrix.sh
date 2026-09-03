#!/usr/bin/env bash
# Launch matrix: the app is reopened with the standard server as default, then
# with the Quick Connect server as default. Checks (from the app log):
#   standard default   → the default is published to the browser within 2s and
#                        BEFORE any tunnel comes up (the queue's Quick Connect
#                        server dials in the background)
#   Quick Connect default → its tunnel comes up, then the browser
#   both               → at most one dial in the first 12s, no "no-target"
#                        teardown (the tunnel-built-then-torn-down churn)
# Needs one Quick Connect and one standard server on the device.
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
IROH=$(localname_of iroh); STD=$(localname_of standard)
if [ -z "$IROH" ] || [ -z "$STD" ]; then skip "needs one Quick Connect and one standard server"; summary; exit; fi

run_case() { # <name> <iroh|standard>
  local name="$1" order="$2"
  log "== $name (order: $(cfg_order "$order"))"
  app_stop; logcat_clear; wake; app_start; sleep 12; shot "$name-12s"; save_applog "$name"
  local started ready up; started=$(first_ts '\[app\] mStream '); ready=$(first_ts '\[app\] default server ready'); up=$(first_ts '\[iroh\] tunnel up')
  local d_ready d_up; d_ready=$(secs_between "$started" "$ready"); d_up=$(secs_between "$started" "$up")
  log "   started→default ready ${d_ready:-?}s · started→tunnel up ${d_up:-never}s"
  if [ "$order" = standard ]; then
    if [ -n "$d_ready" ] && lt "$d_ready" 2.0; then pass "$name: default published in ${d_ready}s"; else fail "$name: default published in ${d_ready:-?}s (limit 2s)"; fi
    if [ -n "$d_up" ]; then
      if lt "$d_ready" "$d_up"; then pass "$name: published before the tunnel came up"; else fail "$name: the browser waited for the tunnel"; fi
    else log "   (no Quick Connect dial in this launch — the saved queue is not on $IROH)"; fi
  else
    if [ -n "$d_up" ] && lt "$d_ready" 15; then pass "$name: tunnel up in ${d_up}s, default published at ${d_ready}s"; else fail "$name: tunnel up ${d_up:-never}, default ready ${d_ready:-never}"; fi
  fi
  local ups stops; ups=$(count_log '\[iroh\] tunnel up'); stops=$(count_log 'tunnel stopped \(no-target')
  if [ "$ups" -le 1 ]; then pass "$name: $ups dial(s)"; else fail "$name: $ups dials in 12s"; fi
  if [ "$stops" -eq 0 ]; then pass "$name: no no-target teardown"; else fail "$name: $stops no-target teardown(s)"; fi
}
run_case standard-default standard
run_case quickconnect-default iroh
summary
