#!/usr/bin/env bash
# Shared helpers for the Android smoke scripts. Source me; do not run.
#
#   ADB               path to adb (default: ~/Library/Android/sdk/platform-tools/adb)
#   SMOKE_ADB_SERIAL  device serial (default: the first attached device)
#   SMOKE_PKG         package id (default: mstream.music.plus.dev — the debug .plus.dev build)
#   SMOKE_OUT         artifact dir (default: smoke/out/<timestamp>-<script>)
#
# Every script writes screenshots + the filtered app log to $OUT and prints
# PASS / FAIL / SKIP lines followed by a summary; the exit code is non-zero on
# any FAIL. Scripts that touch the device's server config back it up first and
# restore it on exit (including Ctrl-C). Pairing codes / tokens are never
# printed — only localnames.
set -u
SMOKE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
PKG="${SMOKE_PKG:-mstream.music.plus.dev}"
ACT="${SMOKE_ACTIVITY:-com.example.mstream_music.MainActivity}"
SERIAL="${SMOKE_ADB_SERIAL:-}"
SCRIPT_NAME="$(basename "${0:-smoke}" .sh)"
OUT="${SMOKE_OUT:-$SMOKE_ROOT/out/$(date +%Y%m%d-%H%M%S)-$SCRIPT_NAME}"
mkdir -p "$OUT"
PASS=0; FAIL=0; SKIP=0

adbx() { if [ -n "$SERIAL" ]; then "$ADB" -s "$SERIAL" "$@"; else "$ADB" "$@"; fi; }
pick_device() {
  if [ -z "$SERIAL" ]; then SERIAL=$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}'); fi
  [ -n "$SERIAL" ] || { echo "no Android device attached"; exit 2; }
  adbx shell pm list packages 2>/dev/null | grep -q "^package:$PKG$" || { echo "$PKG is not installed on $SERIAL"; exit 2; }
  log "device: $SERIAL  package: $PKG"
}
log()  { echo "$(date '+%H:%M:%S') $*" | tee -a "$OUT/run.log"; }
pass() { PASS=$((PASS+1)); log "PASS  $*"; }
fail() { FAIL=$((FAIL+1)); log "FAIL  $*"; }
skip() { SKIP=$((SKIP+1)); log "SKIP  $*"; }
summary() { log "== $SCRIPT_NAME: $PASS pass, $FAIL fail, $SKIP skip — artifacts in $OUT"; [ "$FAIL" -eq 0 ]; }

app_pid()      { adbx shell pidof "$PKG" 2>/dev/null | tr -d '\r '; }
app_start()    { adbx shell am start -n "$PKG/$ACT" >/dev/null; }
app_stop()     { adbx shell am force-stop "$PKG"; }
logcat_clear() { adbx logcat -c; }
# The app's own log lines (Flutter prints) since the last logcat_clear, as "HH:MM:SS.mmm [tag] …".
applog() {
  adbx logcat -d -v time 2>/dev/null | grep "I/flutter" | sed 's/^[0-9-]* //; s/ I\/flutter ( [0-9]*): / /'
}
wait_for_log() { # <regex> <timeout s> → 0 when the line appears
  local pat="$1" t="${2:-30}" i=0
  while [ "$i" -lt "$t" ]; do applog | grep -qE "$pat" && return 0; sleep 1; i=$((i+1)); done
  return 1
}
# Like wait_for_log, but only a line stamped at/after <HH:MM:SS> counts (an
# earlier match from launch or a previous outage must not satisfy a later check).
wait_for_log_after() { # <since HH:MM:SS> <regex> <timeout s>
  local since="$1" pat="$2" t="${3:-30}" i=0 ts
  while [ "$i" -lt "$t" ]; do
    ts=$(applog | grep -E "$pat" | awk -v s="$since" '{ if (substr($1,1,8) >= s) { print substr($1,1,12); exit } }')
    [ -n "$ts" ] && return 0
    sleep 1; i=$((i+1))
  done; return 1
}
ts_after() { applog | grep -E "$2" | awk -v s="$1" '{ if (substr($1,1,8) >= s) { print substr($1,1,12); exit } }'; }
first_ts() { applog | grep -E "$1" | head -1 | cut -c1-12; }
last_ts()  { applog | grep -E "$1" | tail -1 | cut -c1-12; }
count_log() { applog | grep -cE "$1"; }
secs_between() { # <ts a> <ts b> → seconds (b - a), empty if either is missing
  python3 - "$1" "$2" <<'PY'
import sys
def s(t):
    h,m,r=t.split(':'); return int(h)*3600+int(m)*60+float(r)
a,b=sys.argv[1],sys.argv[2]
print(round(s(b)-s(a),1) if a and b else '')
PY
}
lt() { python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "$1" "$2"; }
now_hms() { date '+%H:%M:%S'; }

shot()      { adbx exec-out screencap -p > "$OUT/$1.png" 2>/dev/null; log "shot $1"; }
tap()       { adbx shell input tap "$1" "$2"; }
key()       { adbx shell input keyevent "$1"; }
airplane()  { adbx shell cmd connectivity airplane-mode "$1" >/dev/null; log "airplane $1"; }
wifi()      { adbx shell svc wifi "$1"; log "wifi $1"; }
bluetooth() { adbx shell svc bluetooth "$1" >/dev/null; log "bluetooth $1"; }
# Media keys go through the input pipeline (KEYCODE_MEDIA_*), which the
# session manager routes to the app's registered media button receiver even
# when the app is paused or dead. `cmd media_session dispatch` only reaches a
# session that is currently the media-button session (i.e. played recently).
media_key() { # play | pause | play-pause
  local code; case "$1" in play) code=126;; pause) code=127;; *) code=85;; esac
  adbx shell input keyevent "$code"; log "media key: $1"
}
wake()      { adbx shell input keyevent KEYCODE_WAKEUP; }
bt_connected() { adbx shell dumpsys bluetooth_manager 2>/dev/null | grep -m1 -E "ConnectionState:" | grep -q STATE_CONNECTED; }
a2dp_route()   { adbx shell dumpsys audio 2>/dev/null | grep -m1 -oE 'Devices: (bt_a2dp|speaker)[^ ]*'; }
session_state() { adbx shell dumpsys media_session 2>/dev/null | grep -A8 "$PKG" | grep -m1 -oE 'state=[A-Z_]+\([0-9]\)'; }
is_playing() { session_state | grep -q PLAYING; }
# Start playback if it is not running. A PLAY media key reaches the app as a
# play/pause TOGGLE (audio_service), so it must never be sent to a playing app.
ensure_playing() { # <timeout s> → 0 when PLAYING
  local t="${1:-15}" i=0
  is_playing && return 0
  media_key play
  while [ "$i" -lt "$t" ]; do is_playing && return 0; sleep 1; i=$((i+1)); done
  return 1
}

# ── device config (servers.json / auto_dj.json), backed up + restored on exit ──
CFG_BACKUP=""
cfg_read()  { adbx shell "run-as $PKG cat app_flutter/$1"; }
cfg_write() { adbx push "$2" /data/local/tmp/smoke-cfg >/dev/null
              adbx shell "run-as $PKG sh -c 'cat /data/local/tmp/smoke-cfg > app_flutter/$1'; rm /data/local/tmp/smoke-cfg"; }
cfg_backup() {
  CFG_BACKUP="$OUT/cfg-backup"; mkdir -p "$CFG_BACKUP"
  for f in servers.json auto_dj.json; do cfg_read "$f" > "$CFG_BACKUP/$f"; done
  trap cfg_restore EXIT
}
cfg_restore() {
  [ -n "$CFG_BACKUP" ] || return 0
  app_stop
  for f in servers.json auto_dj.json; do [ -s "$CFG_BACKUP/$f" ] && cfg_write "$f" "$CFG_BACKUP/$f"; done
  rm -rf "$CFG_BACKUP"; CFG_BACKUP=""
  log "device config restored"
}
# Put the Quick Connect server ("iroh") or the standard server ("standard") first; prints the order.
cfg_order() {
  python3 - "$CFG_BACKUP/servers.json" "$1" "$OUT/servers-ordered.json" <<'PY'
import json,sys
src,first,dst=sys.argv[1:]
L=json.load(open(src)); iroh=[s for s in L if s.get('connectionType')=='iroh']; rest=[s for s in L if s.get('connectionType')!='iroh']
out=(iroh+rest) if first=='iroh' else (rest+iroh)
json.dump(out,open(dst,'w')); print(' '.join(s['localname'] for s in out))
PY
  cfg_write servers.json "$OUT/servers-ordered.json"; rm -f "$OUT/servers-ordered.json"
}
cfg_dj() { # point Auto DJ at a localname
  python3 - "$CFG_BACKUP/auto_dj.json" "$1" "$OUT/auto_dj.json" <<'PY'
import json,sys
src,name,dst=sys.argv[1:]; d=json.load(open(src)); d['enabledServer']=name; json.dump(d,open(dst,'w'))
PY
  cfg_write auto_dj.json "$OUT/auto_dj.json"; rm -f "$OUT/auto_dj.json"
}
localname_of() { # iroh|standard → localname from the backup
  python3 -c "
import json,sys
L=json.load(open(sys.argv[1])); kind=sys.argv[2]
m=[s for s in L if (s.get('connectionType')=='iroh')==(kind=='iroh')]
print(m[0]['localname'] if m else '')" "$CFG_BACKUP/servers.json" "$1"
}
save_applog() { applog > "$OUT/$1.log"; }
