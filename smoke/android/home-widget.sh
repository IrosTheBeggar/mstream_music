#!/usr/bin/env bash
# Home-screen widget: the Now Playing widget mirrors the handler (title,
# play/pause icon) and its buttons drive it — with the process alive, and a
# Play tap after the process is killed cold-boots the service headless and
# plays once the handler is up. The placement goes through the app's debug hook
# (`ext.mstream.widget`, debug builds only) plus the launcher's own confirm
# dialog; the widget itself is read and tapped through `uiautomator dump` of
# the launcher, by its English content descriptions (Play / Pause / Next
# track) — run with the phone in English, and with the home page the widget
# lands on in view.
#   SMOKE_WIDGET_PIN=0   never place the widget; only check one already placed
#   SMOKE_ART_URL        a cover URL on one of the phone's configured servers
#                        (…/album-art/…) to push through the fetch chain; on an
#                        emulator the script serves one itself from this Mac
#                        (10.0.2.2 must be a configured server host — a rig is)
# A placed widget stays on the home screen afterwards, which is why the suite
# runs this only with SMOKE_WIDGET=1.
source "$(dirname "$0")/../lib.sh"; pick_device

UI="$OUT/ui.xml"
ui_dump() { adbx shell uiautomator dump /sdcard/smoke-ui.xml >/dev/null 2>&1; adbx shell cat /sdcard/smoke-ui.xml > "$UI" 2>/dev/null; }
# Centre of the first node whose <attr> matches <regex> (case-insensitive), as "x y"; empty when absent.
ui_center() { python3 - "$UI" "$1" "$2" <<'PY'
import re, sys, xml.etree.ElementTree as ET
try: root = ET.parse(sys.argv[1]).getroot()
except Exception: sys.exit(0)
pat = re.compile(sys.argv[3], re.I)
for n in root.iter('node'):
    if pat.search(n.get(sys.argv[2]) or ''):
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds') or '')
        if m:
            x1, y1, x2, y2 = map(int, m.groups()); print((x1 + x2) // 2, (y1 + y2) // 2); break
PY
}
ui_has_text() { python3 - "$UI" "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
try: root = ET.parse(sys.argv[1]).getroot()
except Exception: sys.exit(1)
sys.exit(0 if any((n.get('text') or '') == sys.argv[2] for n in root.iter('node')) else 1)
PY
}
widget_tap() { # <content-desc regex> → 0 when tapped
  ui_dump; local c; c=$(ui_center content-desc "$1"); [ -n "$c" ] || return 1; tap $c; log "widget tap: $1"; }
published_title() { applog | grep -oE '\[widget\] publish .*title="[^"]*"' | tail -1 | sed 's/.*title="//; s/"$//'; }

# ── boot + the debug hook over the VM service ──
app_stop; logcat_clear; wake; app_start; sleep 12
VMURL=$(adbx logcat -d ${APP_UID:+--uid="$APP_UID"} 2>/dev/null | grep -oE 'Dart VM service is listening on http://127.0.0.1:[0-9]+/[^ ]*/' | tail -1 | sed 's/.* on //')
[ -n "$VMURL" ] || { fail "no Dart VM service line — is this a debug build?"; summary; exit 1; }
VMPORT=$(echo "$VMURL" | grep -oE ':[0-9]+/' | tr -dc '0-9'); adbx forward "tcp:$VMPORT" "tcp:$VMPORT" >/dev/null
ISO=$(curl -s --max-time 5 "${VMURL}getVM" | python3 -c "import sys,json; iso=json.load(sys.stdin)['result']['isolates']; print(([i for i in iso if i.get('name')=='main'] or iso)[0]['id'])" 2>/dev/null)
[ -n "$ISO" ] || { fail "VM service unreachable"; summary; exit 1; }
ISOQ=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$ISO")
wx() { curl -s --max-time 20 "${VMURL}ext.mstream.widget?isolateId=${ISOQ}&action=$1" | python3 -c "import sys,json
try: d=json.load(sys.stdin); print(json.dumps(d.get('result', d)))
except Exception: print('{}')"; }
field() { python3 -c "import sys,json; d=json.loads(sys.argv[1]); v=d
for k in sys.argv[2].split('.'): v=v.get(k) if isinstance(v,dict) else None
print('' if v is None else v)" "$1" "$2"; }

# ── placement ──
S=$(wx state); N=$(field "$S" result.native.instances)
log "widget instances: ${N:-?} (session service: $(field "$S" result.native.mediaBrowserService))"
if [ "${N:-0}" = 0 ] && [ "${SMOKE_WIDGET_PIN:-1}" != 0 ]; then
  wx pin >/dev/null; sleep 3; ui_dump
  c=$(ui_center text 'add automatically|add to home|^add$'); [ -n "$c" ] || c=$(ui_center content-desc 'add automatically|add to home|^add$')
  if [ -n "$c" ]; then tap $c; log "accepted the launcher's placement dialog"; sleep 3; S=$(wx state); N=$(field "$S" result.native.instances); fi
fi
if [ "${N:-0}" = 0 ]; then skip "no widget placed (the launcher's dialog was not found) — place one by hand and rerun"; summary; exit 0; fi
pass "widget placed ($N instance(s))"

# ── the launcher shows what Dart published ──
key KEYCODE_HOME; sleep 3; ui_dump
T=$(published_title)
if [ -n "$T" ] && ui_has_text "$T"; then pass "launcher shows the published title: \"$T\""
elif [ -z "$T" ]; then ui_has_text "Nothing playing" && pass "launcher shows the empty state" || fail "nothing published and no empty state on the launcher"
else fail "launcher does not show \"$T\" (is the widget on the visible home page?)"; fi
shot widget-idle

# ── the buttons, process alive ──
A=$(now_ts); ensure_playing 20 || log "(could not start playback)"
wait_for_log_after "$A" '\[widget\] publish hasTrack=true playing=true' 15 && pass "playing published" || fail "no playing publish"
sleep 2; ui_dump; [ -n "$(ui_center content-desc '^pause$')" ] && pass "widget shows Pause while playing" || fail "no Pause button on the launcher"
shot widget-playing

# ── the cover: the real track's when it has one, else a served one through the same chain ──
ART_URL="${SMOKE_ART_URL:-}"; ARTPID=""
if [ -z "$ART_URL" ] && [[ "$SERIAL" == emulator-* ]]; then
  mkdir -p "$OUT/artsrv/album-art"; python3 - "$OUT/artsrv/album-art/smoke.png" <<'PY'
import struct, sys, zlib
w = h = 96
rows = b''.join(b'\x00' + bytes(sum(([(x * 255) // w, 96, 200 - (y * 128) // h] for x in range(w)), [])) for y in range(h))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
PY
  ARTPORT="${SMOKE_ART_PORT:-3199}"
  python3 -m http.server "$ARTPORT" --bind 0.0.0.0 --directory "$OUT/artsrv" >"$OUT/artsrv.log" 2>&1 & ARTPID=$!; sleep 1
  if kill -0 "$ARTPID" 2>/dev/null; then ART_URL="http://10.0.2.2:$ARTPORT/album-art/smoke.png"
  else log "(no cover server: port $ARTPORT is busy — SMOKE_ART_PORT picks another)"; ARTPID=""; fi
fi
if [ -n "$ART_URL" ]; then
  wx "art&url=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$ART_URL")" >/dev/null; sleep 6
  S=$(wx state); [ "$(field "$S" result.native.artCached)" = "True" ] && pass "cover fetched through the art provider and cached" || fail "cover not cached: $S"
  # Fetched now ("render (art)") or already on disk from an earlier run (the
  # publish itself renders it, "art=true").
  adbx logcat -d -s NowPlayingWidget 2>/dev/null | grep -qE "render \((art|publish)\) .*art=true" && pass "widget rendered with the cover" || fail "no cover render in the native log"
  shot widget-art
else
  case "$(adbx logcat -d -s NowPlayingWidget 2>/dev/null | grep -oE 'art: (cached|none|unavailable)|render \(art\)' | tail -1)" in
    "render (art)"|"art: cached") pass "cover rendered for the playing track";;
    "art: none") skip "the playing track has no cover (set SMOKE_ART_URL for the fetch check)";;
    *) fail "cover fetch failed for the playing track";;
  esac
fi
A=$(now_ts); widget_tap '^pause$' && wait_for_log_after "$A" '\[play\] pause' 10 && pass "widget Pause → handler pause" || fail "widget Pause did not pause"
sleep 2; ui_dump; [ -n "$(ui_center content-desc '^play$')" ] && pass "widget shows Play while paused" || fail "no Play button after the pause"
A=$(now_ts); widget_tap '^play$' && wait_for_log_after "$A" '\[play\] play' 10 && pass "widget Play → handler play" || fail "widget Play did not play"
# Skip away from the current track: Next, unless this is the queue's last
# track (repeat off has nowhere to go from there), then Previous.
T0=$(published_title); POS=$(applog | grep -oE '\[play\] track [0-9]+/[0-9]+' | tail -1 | grep -oE '[0-9]+/[0-9]+')
if [ -n "$POS" ] && [ "${POS%/*}" -ge "${POS#*/}" ]; then SKIPBTN='^previous track$'; SKIPNAME=Previous; else SKIPBTN='^next track$'; SKIPNAME=Next; fi
A=$(now_ts); widget_tap "$SKIPBTN" && wait_for_log_after "$A" '\[play\] track ' 15 && pass "widget $SKIPNAME → skipped (was $POS)" || fail "widget $SKIPNAME did not skip (was $POS)"
sleep 3; ui_dump; T=$(published_title)
if [ -n "$T" ] && [ "$T" != "$T0" ] && ui_has_text "$T"; then pass "title followed the skip: \"$T0\" → \"$T\""; else fail "launcher shows \"$T\" after the skip from \"$T0\""; fi
shot widget-after-skip

# ── a Play tap after the process is killed (the way the OS reclaims it; not force-stop) ──
widget_tap '^pause$'; sleep 3
PID=$(app_pid); adbx shell "run-as $PKG kill -9 $PID" 2>/dev/null; sleep 3
if [ -z "$(app_pid)" ]; then
  log "process $PID killed"; logcat_clear
  widget_tap '^play$' || fail "no Play button after the kill"
  wait_for_log '\[app\] mStream ' 20 && pass "widget Play cold-booted the service headless" || fail "no headless boot within 20s"
  wait_for_log '\[play\] play' 30 && wait_playing 20 && pass "playback resumed ($(session_state))" || fail "no playback within 50s ($(session_state))"
  wait_for_log '\[widget\] publish hasTrack=true playing=true' 30 && pass "widget re-published after the boot" || fail "no publish after the boot"
  shot widget-after-kill
else fail "could not kill the process"; fi
adbx logcat -d -s NowPlayingWidget 2>/dev/null | grep -v "^-" > "$OUT/native.log"
save_applog home-widget; adbx forward --remove "tcp:$VMPORT" >/dev/null 2>&1; [ -n "$ARTPID" ] && kill "$ARTPID" 2>/dev/null
summary
