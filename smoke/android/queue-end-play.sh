#!/usr/bin/env bash
# Play after the queue has run out. A fresh local mStream with four
# fifteen-second tracks of silence the script writes itself, and one account;
# the app restores three of them and plays to the end of the queue, where the
# handler stops. The stop leaves the player on the finished track holding its
# END as the position, and a re-seed loaded there: ready, completed in the
# same breath, stopped again — Play did nothing (2026-11-16). So:
#
#   1. PLAY starts the last track from the top, and it is still playing five
#      seconds later.
#   2. a STOP in the middle of that replay, then PLAY, resumes where it was
#      stopped: only a queue that played out starts over.
#   3. with a track queued after the end, PLAY goes on to it instead of
#      through the finished one again.
#   4. a relaunch onto a snapshot that names the END of its last track opens
#      at the track's start, and the first PLAY plays it. The app saves 0:00
#      for a track whose length it knows, so the snapshot is planted with no
#      lengths in it: the one the snapshot's own clamp cannot judge.
#   5. the same relaunch with the server down. The restore's load fails and
#      the spot is parked, the retries run out, the server comes back, and
#      the first PLAY is what loads the spot: it plays from the start too.
#   6. once that replay has played out: the finished row is removed, and the
#      row left current does not inherit its position; then Clear queue, and
#      nothing is loaded at 0:00 with no track on the media session.
#
#   SMOKE_SRC           mStream checkout to boot (default ~/code/mstream)
#   SMOKE_HOST          how the phone reaches this Mac: 10.0.2.2 on the
#                       emulator (default), the Mac's LAN address on a phone
#   SMOKE_PORT          the server's port (default 3173)
#   SMOKE_MINI_PLAY_XY  the mini player's Play button, used only when the PLAY
#                       key finds no taker: Android has no media-button target
#                       on a device where nothing has played yet (default: the
#                       1080-wide layout, 134 px above the bottom edge)
#
# Steps 3 and 6 find their rows and buttons by label (English) and are
# skipped when they cannot: build with --dart-define=SMOKE_SEMANTICS=true.
source "$(dirname "$0")/../lib.sh"; pick_device
SRC="${SMOKE_SRC:-$HOME/code/mstream}"
HOST="${SMOKE_HOST:-10.0.2.2}"
PORT="${SMOKE_PORT:-3173}"
NAME="queue-end-rig"
J='Content-Type: application/json'
[ -f "$SRC/cli-boot-wrapper.js" ] || { echo "no mStream checkout at $SRC (SMOKE_SRC)"; exit 2; }

ui_dump() { adbx shell uiautomator dump /sdcard/smoke-ui.xml >/dev/null 2>&1; adbx shell cat /sdcard/smoke-ui.xml 2>/dev/null; }
tap_text() { # <needle> → 0 when tapped
  local xy
  xy=$(ui_dump | python3 -c '
import re,sys
needle=sys.argv[1]; s=sys.stdin.read()
for m in re.finditer(r"<node [^>]*>", s):
    n=m.group(0)
    t=re.search(r"text=\"([^\"]*)\"", n); d=re.search(r"content-desc=\"([^\"]*)\"", n)
    txt=(t.group(1) if t else "")+" "+(d.group(1) if d else "")
    if needle in txt:
        b=re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", n)
        if b:
            x1,y1,x2,y2=map(int,b.groups()); print((x1+x2)//2,(y1+y2)//2); break
' "$1")
  [ -n "$xy" ] || return 1
  # shellcheck disable=SC2086
  tap $xy; log "tap '$1' at $xy"
}
# The media session's position right now in ms, run forward from its last
# update while playing; -1 when there is no session.
pos_ms() {
  local up; up=$(adbx shell cat /proc/uptime | awk '{printf "%d", $1*1000}')
  adbx shell dumpsys media_session 2>/dev/null | grep -A14 "$PKG" | grep -m1 "state=PlaybackState" | python3 -c '
import re,sys
up=int(sys.argv[1]); s=sys.stdin.read()
m=re.search(r"state=\w+\((\d)\), position=(\d+), buffered position=\d+, speed=([\d.]+), updated=(\d+)", s)
if not m: print(-1); sys.exit()
st,pos,speed,upd=int(m.group(1)),int(m.group(2)),float(m.group(3)),int(m.group(4))
print(int(pos+(up-upd)*speed) if st==3 else pos)' "$up"
}
queue_index() { adbx shell dumpsys media_session 2>/dev/null | grep -A14 "$PKG" | grep -m1 -oE 'active item id=[0-9]+' | tr -dc '0-9'; }
# What the media session says is playing, e.g. "Quiet Two, Queue End Rig, Queue End".
now_playing() { adbx shell dumpsys media_session 2>/dev/null | grep -A14 "$PKG" | grep -m1 -oE 'description=.*' | cut -d= -f2-; }
# Centres ("x y") of the nodes whose text or content-desc is <needle> — exactly
# with a leading "=", as a substring otherwise. Top of the screen first.
nodes() {
  ui_dump | python3 -c '
import re,sys
needle=sys.argv[1]; exact=needle.startswith("=")
if exact: needle=needle[1:]
for m in re.finditer(r"<node [^>]*>", sys.stdin.read()):
    n=m.group(0)
    t=re.search(r"text=\"([^\"]*)\"", n); d=re.search(r"content-desc=\"([^\"]*)\"", n)
    vals=[t.group(1) if t else "", d.group(1) if d else ""]
    hit=any(v==needle for v in vals) if exact else any(needle in v for v in vals)
    b=re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", n)
    if hit and b:
        x1,y1,x2,y2=map(int,b.groups()); print((x1+x2)//2,(y1+y2)//2)
' "$1"
}
# The app's log lines stamped at/after <ts> that match <regex>.
count_after() { applog | awk -v s="$1" 'substr($1,1,12) >= s' | grep -cE "$2"; }
TOP='\[play\] the queue had ended — track [0-9]+ starts from the top'
ENDED='\[play\] completed → stop'

# ── the library: four quarter-minute tracks of silence ──
MUSIC="$OUT/music"; mkdir -p "$MUSIC/Queue End"
python3 - "$MUSIC/Queue End" <<'PY'
import sys, wave
for n, name in enumerate(["One", "Two", "Three", "Four"], 1):
    with wave.open(f"{sys.argv[1]}/{n:02d} Quiet {name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(22050)
        w.writeframes(bytes(2 * 22050 * 15))
PY

# ── the server ──
RIG="$OUT/srv"; mkdir -p "$RIG/db" "$RIG/art" "$RIG/logs" "$RIG/waveform"
ADDR=127.0.0.1; [ "$HOST" = 10.0.2.2 ] || ADDR=0.0.0.0
python3 - "$RIG" "$PORT" "$ADDR" "$MUSIC" <<'PY'
import json,sys
rig,port,addr,music=sys.argv[1:]
json.dump({"port":int(port),"address":addr,"dlna":{"mode":"disabled"},"folders":{"demo":{"root":music}},
           "storage":{"albumArtDirectory":rig+"/art","dbDirectory":rig+"/db","logsDirectory":rig+"/logs","waveformCacheDirectory":rig+"/waveform"},
           "scanOptions":{"bootScanDelay":1,"scanInterval":0,"autoAlbumArt":False,"collectDiscoveryData":False,"analyzeBpm":False}}, open(rig+"/config.json","w"))
PY
if lsof -ti "tcp:$PORT" -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT is in use — free it or set SMOKE_PORT"; exit 2; fi
# exec, so SRV_PID is node itself and the exit trap really kills it.
(cd "$SRC" && exec env NODE_ENV=test node cli-boot-wrapper.js -j "$RIG/config.json" >> "$RIG/server.log" 2>&1) &
SRV_PID=$!
SETTINGS_BACKUP="$OUT/settings-backup.json"
cleanup() {
  kill -9 "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null
  app_stop
  # Back to the settings the phone had; none at all if it had none.
  if [ -s "$SETTINGS_BACKUP" ]; then cfg_write settings.json "$SETTINGS_BACKUP"
  elif [ -e "$SETTINGS_BACKUP" ]; then adbx shell "run-as $PKG rm -f app_flutter/settings.json"; fi
  rm -rf "$SETTINGS_BACKUP" "$MUSIC"
  cfg_restore
}
trap cleanup EXIT
UP=0; for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$PORT/api/" && { UP=1; break; }; sleep 1; done
[ "$UP" = 1 ] || { fail "server did not come up (see $RIG/server.log)"; summary; exit 1; }
curl -s -o /dev/null -X PUT "http://127.0.0.1:$PORT/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["demo"],"admin":true}'
TOKEN=$(curl -s -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { fail "could not log in to the rig server"; summary; exit 1; }
N=0
for _ in $(seq 1 60); do
  curl -s -X POST "http://127.0.0.1:$PORT/api/v1/db/recent/added" -H "$J" -H "x-access-token: $TOKEN" -d '{"limit":20}' > "$OUT/tracks.json" 2>/dev/null
  N=$(python3 -c "import json,sys
try: print(len(json.load(open(sys.argv[1]))))
except Exception: print(0)" "$OUT/tracks.json")
  [ "$N" -ge 4 ] && break; sleep 1
done
[ "$N" -ge 4 ] || { fail "the boot scan found $N of the four tracks"; summary; exit 1; }
log "server $NAME on :$PORT (phone side http://$HOST:$PORT), user rig, $N tracks"

# ── the phone ──
cfg_backup; cfg_read settings.json > "$SETTINGS_BACKUP" 2>/dev/null; trap cleanup EXIT
python3 - "$CFG_BACKUP/servers.json" "$OUT/servers.json" "http://$HOST:$PORT" "$TOKEN" "$NAME" <<'PY'
import json,sys
src,dst,url,tok,name=sys.argv[1:]
try: L=json.load(open(src))
except Exception: L=[]
L=[s for s in L if s.get('localname')!=name]
b={"url":url,"jwt":tok,"username":"rig","password":"rigpw","localname":name,"autoDJPaths":{},"autoDJminRating":None,"autoDJGenreEnabled":False,"autoDJGenreMode":"whitelist","autoDJGenres":[],"playlists":[],"allowSelfSigned":False,"storageMode":"appLocal","storageBasePath":None,"transcodeAvailable":None,"transcodeDefaultCodec":None,"transcodeDefaultBitrate":None,"discoveryAvailable":None,"federationDiscoveryAvailable":None,"discoveryPathAvailable":None,"connectionType":"http","irohPairingCode":None,"serverVersion":None,"versionCheckedAt":None}
json.dump([b]+L, open(dst,'w'))
PY
# Three of the four, restored on the second: one track change, then the end.
python3 - "$OUT/tracks.json" "$OUT/queue.json" "$NAME" <<'PY'
import json,sys
tracks,dst,name=sys.argv[1:]
items=[]
for t in sorted(json.load(open(tracks)), key=lambda t: t['filepath'])[:3]:
    m=t.get('metadata') or {}; p='/'+t['filepath']
    items.append({"id":p,"title":m.get('title') or p.split('/')[-1],"album":m.get('album'),"artist":m.get('artist'),"genre":None,
                  "durationMs":int((m.get('duration') or 0)*1000) or None,
                  "extras":{"server":name,"path":p,"year":m.get('year'),"track":m.get('track'),"disc":m.get('disc'),"rating":None,"artUrl":None,
                            "bpm":None,"musicalKey":None,"bitrate":None,"sampleRate":None,"format":None,"trackTotal":None,"discTotal":None,
                            "playCount":None,"lastPlayed":None,"hash":m.get('hash'),"hasLyrics":False}})
json.dump({"version":1,"index":1,"positionMs":0,"shuffle":False,"repeat":"none","items":items}, open(dst,'w'))
print(' | '.join(i['title'] for i in items))
PY
# A tap on a row must only queue it (step 3), and the queue must come back.
python3 - "$SETTINGS_BACKUP" "$OUT/settings.json" <<'PY'
import json,sys
src,dst=sys.argv[1:]
try: d=json.load(open(src))
except Exception: d={}
d['tapBehavior']='addToQueue'; d['resumeQueue']=True
json.dump(d, open(dst,'w'))
PY
# Auto DJ would top the queue up at its last track, and it would never end.
python3 - "$CFG_BACKUP/auto_dj.json" "$OUT/auto_dj.json" <<'DJOFF'
import json, sys
src, dst = sys.argv[1:]
try:
    d = json.load(open(src))
except Exception:
    d = {}
d['enabledServer'] = None
json.dump(d, open(dst, 'w'))
DJOFF
app_stop
adbx shell "run-as $PKG mkdir -p app_flutter"
cfg_write servers.json "$OUT/servers.json"; cfg_write queue.json "$OUT/queue.json"
cfg_write settings.json "$OUT/settings.json"; cfg_write auto_dj.json "$OUT/auto_dj.json"
rm -f "$OUT/auto_dj.json" "$OUT/settings.json"
logcat_clear; wake; app_start
wait_for_log "\[app\] default server ready: $NAME" 40 && pass "app launched on $NAME" || { fail "app did not settle on $NAME"; save_applog launch; summary; exit 1; }
sleep 10 # a PLAY key in the first seconds after a cold start is dropped

# ── 0. the queue plays out and the handler stops ──
if ! ensure_playing 8; then
  H=$(adbx shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f2)
  # shellcheck disable=SC2086
  tap ${SMOKE_MINI_PLAY_XY:-174 $((H - 134))}; log "no taker for the PLAY key — tapped the mini player's Play"
  wait_playing 15 || { fail "playback did not start from the restored queue"; save_applog play; summary; exit 1; }
fi
wait_for_log "$ENDED" 60 || { fail "the queue did not play out in 60 s"; save_applog end; summary; exit 1; }
sleep 2
LAST=$(queue_index)
if ! is_playing && [ "$LAST" = 2 ]; then pass "the queue played out and stopped on its last track"
else fail "after the end: $(session_state), row ${LAST:-?} (expected stopped on row 2)"; fi

# ── 1. PLAY starts the last track from the top, and it keeps playing ──
T1=$(now_ts); media_key play
wait_for_log_after "$T1" "$TOP" 8 && pass "PLAY after the end: the last track starts from the top" || fail "no 'the queue had ended — … starts from the top' line after the PLAY key"
wait_playing 10 && pass "the session reaches PLAYING" || fail "the session never reached PLAYING ($(session_state))"
sleep 5
P1=$(pos_ms); P1=${P1:--1}; I1=$(queue_index); E1=$(count_after "$T1" "$ENDED")
if is_playing && [ "$I1" = 2 ] && [ "$E1" = 0 ] && [ "$P1" -ge 2500 ] && [ "$P1" -le 12000 ]; then
  pass "still playing five seconds on, ${P1} ms into the last track"
else
  fail "five seconds on: $(session_state), row ${I1:-?}, ${P1} ms, $E1 more queue end(s) — the load completed at once again?"
fi

# ── 2. a STOP mid-track is not a queue end: PLAY resumes where it stopped ──
T3=$T1
if ! is_playing; then
  skip "stop mid-track — nothing is playing to stop"
else
  T2=$(now_ts); key 86; log "media key: stop"
  wait_for_log_after "$T2" '\[play\] stop' 5 || fail "the STOP key did not reach the handler"
  sleep 1; P2=$(pos_ms); P2=${P2:--1}
  T3=$(now_ts); media_key play
  wait_playing 10
  P3=$(pos_ms); P3=${P3:--1}; TOPS=$(count_after "$T3" "$TOP")
  if is_playing && [ "$TOPS" = 0 ] && [ "$P2" -ge 2500 ] && [ "$P3" -ge $((P2 - 1500)) ]; then
    pass "a stop mid-track resumes at its spot (${P2} ms → ${P3} ms)"
  else
    fail "after a stop mid-track: $(session_state), ${P2} ms → ${P3} ms, $TOPS 'from the top' line(s) — it must resume, not start over"
  fi
fi

# ── 3. a track queued after the end: PLAY goes on to it ──
# The replay plays out first (on a build with the bug it never started, and
# the queue is already at its end).
if is_playing; then wait_for_log_after "$T3" "$ENDED" 30 || fail "the replay did not play out"; fi
sleep 2
T4=$(now_ts)
if ! tap_text "File Explorer"; then
  skip "queued-after-the-end — no 'File Explorer' on screen (a build without --dart-define=SMOKE_SEMANTICS=true, a dialog, or another language)"
else
  sleep 2; tap_text "Queue End" && sleep 2 && tap_text "Quiet Four"
  if wait_for_log_after "$T4" '\[queue\] add: .*\(now 4\)' 8; then
    T5=$(now_ts); media_key play
    wait_playing 10; sleep 2
    I5=$(queue_index); TOPS=$(count_after "$T5" "$TOP")
    if is_playing && [ "$I5" = 3 ] && [ "$TOPS" = 0 ]; then
      pass "with a track queued after the end, PLAY goes on to it"
    else
      fail "queued-after-the-end: $(session_state), row ${I5:-?} (expected 3), $TOPS 'from the top' line(s)"
    fi
  else
    fail "could not queue a fourth track through File Explorer"; shot queue-after-end
  fi
fi

# ── 4. a relaunch onto a snapshot saved at the end of its last track ──
# The three tracks again, restored on the last one just past its fifteen
# seconds, with no length on any item. The restore used to park there, ready
# and paused on the last sample, and the first PLAY completed on the spot.
app_stop
python3 - "$OUT/queue.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d['index'] = len(d['items']) - 1; d['positionMs'] = 15050
for i in d['items']: i['durationMs'] = None
json.dump(d, open(p, 'w'))
PY
cfg_write queue.json "$OUT/queue.json"
T6=$(now_ts); wake; app_start
if ! wait_for_log_after "$T6" "\[app\] default server ready: $NAME" 40; then
  fail "the relaunch did not settle on $NAME"
else
  sleep 10 # as at the first launch: an early PLAY key is dropped
  P6=$(pos_ms); P6=${P6:--1}; I6=$(queue_index)
  if ! is_playing && [ "$I6" = 2 ] && [ "$P6" -ge 0 ] && [ "$P6" -le 1000 ]; then
    pass "a snapshot at the end of its last track opens at the track's start"
  else
    fail "after the relaunch: $(session_state), row ${I6:-?}, ${P6} ms (expected paused on row 2 at its start)"
  fi
  T7=$(now_ts); media_key play
  wait_playing 10; sleep 5
  P7=$(pos_ms); P7=${P7:--1}; I7=$(queue_index); E7=$(count_after "$T7" "$ENDED")
  if is_playing && [ "$I7" = 2 ] && [ "$E7" = 0 ] && [ "$P7" -ge 2500 ] && [ "$P7" -le 12000 ]; then
    pass "the first PLAY after that relaunch plays the last track (${P7} ms in, five seconds on)"
  else
    fail "the first PLAY after the relaunch: $(session_state), row ${I7:-?}, ${P7} ms, $E7 queue end(s) — it completed on the spot?"
  fi
fi

# ── 5. the same relaunch, with the server out of reach at launch ──
# The snapshot again (the app has saved its own over it since). This time
# the restore cannot load it: the spot is parked as saved, and whatever
# loads it later has to make the same check. Here that is the first PLAY,
# pressed once the app's retries have run out and the server is back.
app_stop
cfg_write queue.json "$OUT/queue.json"
kill -9 "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null
T8=$(now_ts); wake; app_start
if ! wait_for_log_after "$T8" '\[queue\] restore load failed' 40; then
  fail "the restore's load did not fail with the server down"
else
  wait_for_log_after "$T8" '\[play\] retry 3 did not load' 60 || log "the retries were not spent in 60 s — going on"
  sleep 2 # the walk's own stop, after the last retry
  (cd "$SRC" && exec env NODE_ENV=test node cli-boot-wrapper.js -j "$RIG/config.json" >> "$RIG/server.log" 2>&1) &
  SRV_PID=$!
  UP=0; for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$PORT/api/" && { UP=1; break; }; sleep 1; done
  if [ "$UP" != 1 ]; then
    fail "the server did not come back (see $RIG/server.log)"
  else
    T9=$(now_ts); media_key play
    wait_playing 15; sleep 5
    P9=$(pos_ms); P9=${P9:--1}; I9=$(queue_index); E9=$(count_after "$T9" "$ENDED")
    if is_playing && [ "$I9" = 2 ] && [ "$E9" = 0 ] && [ "$P9" -ge 2500 ] && [ "$P9" -le 12000 ]; then
      pass "server down at launch: the first PLAY once it is back plays the last track (${P9} ms in, five seconds on)"
    else
      fail "server down at launch: after the first PLAY $(session_state), row ${I9:-?}, ${P9} ms, $E9 queue end(s) — the parked spot was loaded at its end?"
    fi
  fi
fi

# ── 6. the stopped player's position goes with the row it belonged to ──
# The replay plays out, so the player is stopped on the last row holding its
# end. Removing that row slid the row above under the same position, and
# Clear queue left it showing with nothing loaded; both were also what the
# next snapshot saved.
if is_playing; then wait_for_log_after "$T8" "$ENDED" 40 || fail "the replay did not play out"; fi
sleep 2
W=$(adbx shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f1)
H=$(adbx shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f2)
adbx shell input swipe $((W / 2)) $((H - 310)) $((W / 2)) $((H * 29 / 100)) 300; sleep 2 # the queue panel
ROW=$(nodes "Quiet Three" | sort -k2,2n | tail -1) # the list row, below the header that names it too
if is_playing || [ -z "$ROW" ]; then
  skip "removed-row — the stopped last row is not on screen (a build without --dart-define=SMOKE_SEMANTICS=true, another language, or the queue panel did not open)"
else
  RY=${ROW#* }
  adbx shell input swipe $((W * 74 / 100)) "$RY" $((W * 14 / 100)) "$RY" 250; sleep 2 # reveals Remove
  XY=$(nodes "=Remove" | head -1)
  # shellcheck disable=SC2086
  [ -n "$XY" ] && tap $XY
  sleep 4
  P10=$(pos_ms); P10=${P10:--1}; I10=$(queue_index); N10=$(now_playing)
  if [ -n "$XY" ] && [ "$I10" = 1 ] && [ "$P10" = 0 ]; then
    pass "the finished row removed: the row left current is at 0:00 ($N10)"
  else
    fail "after removing the finished row: row ${I10:-?} at ${P10} ms ($N10) — expected row 1 at 0, not the removed track's end"
  fi
fi
XY=$(nodes "=More" | head -1)
if [ -z "$XY" ]; then
  skip "clear-queue — no 'More' on the queue panel"
else
  T11=$(now_ts)
  # shellcheck disable=SC2086
  tap $XY; sleep 2
  XY=$(nodes "=Clear queue" | head -1)
  # shellcheck disable=SC2086
  [ -n "$XY" ] && tap $XY
  if wait_for_log_after "$T11" '\[queue\] cleared' 8; then
    sleep 3
    P11=$(pos_ms); P11=${P11:--1}; N11=$(now_playing)
    if [ "$P11" = 0 ] && ! echo "$N11" | grep -q "Quiet"; then
      pass "Clear queue: nothing loaded, at 0:00 ($N11)"
    else
      fail "after Clear queue: ${P11} ms, the session shows '$N11' — expected 0 and no track"
    fi
  else
    fail "Clear queue did not reach the handler"; shot clear-queue
  fi
fi

save_applog queue-end
summary
