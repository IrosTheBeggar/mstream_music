#!/usr/bin/env bash
# The media session must advertise SET_REPEAT_MODE and SET_SHUFFLE_MODE (the
# lock-screen / Android Auto / CarPlay shuffle-repeat controls hang off them).
source "$(dirname "$0")/../lib.sh"; pick_device
[ -n "$(app_pid)" ] || { wake; app_start; sleep 12; }
ACTIONS=$(adbx shell dumpsys media_session 2>/dev/null | grep -A12 "$PKG" | grep -m1 -oE 'actions=[0-9]+' | cut -d= -f2)
[ -n "$ACTIONS" ] || { fail "no media session for $PKG"; summary; exit 1; }
log "actions bitmask: $ACTIONS"
python3 -c "import sys; a=int(sys.argv[1]); sys.exit(0 if a & (1<<18) else 1)" "$ACTIONS" && pass "SET_REPEAT_MODE advertised" || fail "SET_REPEAT_MODE missing"
python3 -c "import sys; a=int(sys.argv[1]); sys.exit(0 if a & (1<<21) else 1)" "$ACTIONS" && pass "SET_SHUFFLE_MODE advertised" || fail "SET_SHUFFLE_MODE missing"
summary
