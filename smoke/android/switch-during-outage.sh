#!/usr/bin/env bash
# Switch to the standard server while the Quick Connect tunnel is reconnecting
# (airplane mode). Checks: the switch is logged within 2s of the tap (the
# browser reset does not wait on the tunnel chain) and the screenshots show
# the standard server's home grid with NO tunnel strip. The strip and the
# browser are visual — eyeball $OUT/after-switch-*.png.
#   SMOKE_ALBUMS_XY        Albums tile          (default "281 1030", Galaxy S25 1080x2340)
#   SMOKE_PICKER_XY        app-bar server picker (default "1007 187")
#   SMOKE_PICKER_ROW2_XY   second row of the picker (default "782 366")
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
IROH=$(localname_of iroh); STD=$(localname_of standard)
if [ -z "$IROH" ] || [ -z "$STD" ]; then skip "needs one Quick Connect and one standard server"; summary; exit; fi
ALBUMS=${SMOKE_ALBUMS_XY:-"281 1030"}; PICKER=${SMOKE_PICKER_XY:-"1007 187"}; ROW2=${SMOKE_PICKER_ROW2_XY:-"782 366"}
trap 'airplane disable; cfg_restore' EXIT
log "order: $(cfg_order iroh)"
app_stop; logcat_clear; wake; app_start
wait_for_log '\[iroh\] tunnel up' 20 || { fail "tunnel did not come up at launch"; summary; exit 1; }
sleep 2; tap $ALBUMS; sleep 3; shot before-outage
airplane enable
if wait_for_log 'status connected → reconnecting' 75; then pass "supervisor reconnecting after the drop"; else fail "no reconnecting edge within 75s"; fi
tap $PICKER; sleep 1.5; TAP=$(now_hms); tap $ROW2; sleep 0.7; shot after-switch-0.7s; sleep 3; shot after-switch-3.7s
if wait_for_log "\[srv\] switched to $STD" 5; then
  d=$(secs_between "$TAP" "$(first_ts "\[srv\] switched to $STD")")
  if lt "$d" 2.0; then pass "switch logged ${d}s after the tap"; else fail "switch logged ${d}s after the tap"; fi
else fail "no '[srv] switched to $STD' line"; fi
BACK=$(now_hms); airplane disable
wait_for_log_after "$BACK" 'reconnected: attempt|tunnel up' 60 && pass "tunnel back after service returned" || fail "tunnel not back within 60s"
save_applog switch; log "inspect $OUT/after-switch-*.png: standard server header, home grid, no 'Reconnecting…' strip"
summary
