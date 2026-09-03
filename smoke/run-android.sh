#!/usr/bin/env bash
# Runs the Android suite in order and prints one summary. Skip the long soak
# with SMOKE_SOAK_MIN=10; the cast test is opt-in (SMOKE_CAST=1) because it
# plays audio on a TV.
cd "$(dirname "$0")" || exit 2
mkdir -p out
scripts="android/session-actions.sh android/launch-matrix.sh android/switch-during-outage.sh android/media-resumption.sh android/bt-late-pause.sh android/dead-zone.sh android/playback-soak.sh"
[ "${SMOKE_CAST:-0}" = 1 ] && scripts="$scripts android/cast-through-rebuild.sh"
summary=""
for s in $scripts; do
  echo; echo "########## $s"
  if bash "$s"; then r=ok; else r=FAIL; fi
  summary="$summary
$(printf '%-36s %s' "$s" "$r")"
done
echo; echo "== suite$summary"
