#!/usr/bin/env bash
# Casting from the Quick Connect server while its tunnel is disturbed. Plays
# audio on the renderer (a TV) — run it when that is acceptable. Wi-Fi is
# toggled off for 40s (the renderer and the tunnel both drop), then back on:
# the tunnel must reconnect and the cast must either survive or fall back to
# the phone cleanly (no silent dead cast). The outcome is read from the log —
# check $OUT/cast.log by hand for the cast lines.
#   SMOKE_CAST_ICON_XY  app-bar cast icon (default "863 187")
#   SMOKE_CAST_ROW_XY   the renderer's row in the sheet (default "363 1638", second row)
source "$(dirname "$0")/../lib.sh"; pick_device; cfg_backup
ICON=${SMOKE_CAST_ICON_XY:-"863 187"}; ROW=${SMOKE_CAST_ROW_XY:-"363 1638"}
trap 'wifi enable; cfg_restore' EXIT
log "order: $(cfg_order iroh)"
app_stop; logcat_clear; wake; app_start
wait_for_log '\[iroh\] tunnel up' 20 || { fail "no tunnel at launch"; summary; exit 1; }
media_key play; sleep 5; tap $ICON; sleep 5; shot cast-sheet; tap $ROW; sleep 15; shot casting
wifi disable; sleep 40; wifi enable
wait_for_log 'reconnected: attempt|tunnel up' 90 && pass "tunnel back after Wi-Fi returned" || fail "tunnel not back"
sleep 15; shot after; save_applog cast
log "read $OUT/cast.log for the cast outcome (survived / fell back to the phone)"
summary
