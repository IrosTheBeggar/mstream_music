#!/usr/bin/env bash
# The two playback engines on the same round. A fresh local mStream with the
# demo library and one account; the app restores a five-track queue and plays
# it on just_audio's own engine, is switched to the in-repo Media3 engine in
# the middle of a track (Settings › New audio engine), put through transport,
# a stop, a relaunch and a dead server, then switched back and the dead
# server repeated on just_audio. The two outage logs must read the same line
# for line: the handler's recovery is written against just_audio's exact
# sequence of states and errors, so that sequence is what "the same
# behaviour" means for an engine underneath it.
#
# The outage is the case that wedged the first build of the Media3 engine:
# the server goes away and a skip asks for a track nothing of which is
# buffered, so the player errors with that seek still unanswered. An engine
# that answers it then lets just_audio start a native player of its own under
# the app's recovery, the two interrupt each other, and every retry reads
# "Loading interrupted" until a stop. So the round also fails on that line,
# and on a native player that was made and never released.
#
#   SMOKE_SRC    mStream checkout to boot (default ~/code/mstream)
#   SMOKE_MUSIC  library root (default ~/code/mstream-demo-music); needs five
#                tracks of three minutes or more
#   SMOKE_HOST   how the phone reaches this Mac: 10.0.2.2 on the emulator
#                (default), the Mac's LAN address on a real phone
#   SMOKE_PORT   the server's port (default 3171)
#
# Needs a debug build with --dart-define=SMOKE_SEMANTICS=true: the switch is
# found by its label. Android only (the choice does not exist elsewhere).
source "$(dirname "$0")/../lib.sh"; pick_device
SRC="${SMOKE_SRC:-$HOME/code/mstream}"
MUSIC="${SMOKE_MUSIC:-$HOME/code/mstream-demo-music}"
HOST="${SMOKE_HOST:-10.0.2.2}"
PORT="${SMOKE_PORT:-3171}"
NAME="engine-rig"
J='Content-Type: application/json'
[ -f "$SRC/cli-boot-wrapper.js" ] || { echo "no mStream checkout at $SRC (SMOKE_SRC)"; exit 2; }
[ -d "$MUSIC" ] || { echo "no library at $MUSIC (SMOKE_MUSIC)"; exit 2; }

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
saved_engine() { cfg_read settings.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('media3Engine'))" 2>/dev/null; }
# The Media3 engine's own lines (one when a native player is made, one when
# it is released), gathered at every checkpoint so a wrapped logcat between
# two of them loses nothing.
ENGINE_LOG="$OUT/engine.log"; : > "$ENGINE_LOG"
engine_sync() {
  adbx logcat -d -v time ${APP_UID:+--uid="$APP_UID"} 2>/dev/null | grep "Media3Engine" | grep -E "on Media3|released" >> "$ENGINE_LOG"
  sort -u -o "$ENGINE_LOG" "$ENGINE_LOG"
}
players_made() { grep -c "on Media3" "$ENGINE_LOG"; }
# Players of the app's CURRENT process that were made and not released. One
# that died with a killed process (the relaunch below) left no line and is
# not a leak.
players_alive() {
  python3 - "$ENGINE_LOG" "$(app_pid)" <<'PY'
import re,sys
alive=set()
for line in open(sys.argv[1]):
    m=re.search(r"Media3Engine\(\s*(\d+)\): player (\S+) (on Media3|released)", line)
    if not m or m.group(1)!=sys.argv[2]: continue
    (alive.add if m.group(3)=="on Media3" else alive.discard)(m.group(2))
print(len(alive))
PY
}

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
SRV_PID=""
server_start() { # boots (or re-boots, on the same database) and waits for it to answer
  # exec, so SRV_PID is node itself and the exit trap really kills it.
  (cd "$SRC" && exec env NODE_ENV=test node cli-boot-wrapper.js -j "$RIG/config.json" >> "$RIG/server.log" 2>&1) &
  SRV_PID=$!
  for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$PORT/api/" && return 0; sleep 1; done
  return 1
}
# SIGKILL, not a shutdown: mStream closes gracefully and goes on feeding a
# stream that is already open, and a player with that stream plays on for a
# minute of "outage". A network that drops does not finish its downloads.
server_stop() { [ -n "$SRV_PID" ] && kill -9 "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""; log "server down"; }
SETTINGS_BACKUP="$OUT/settings-backup.json"
cleanup() {
  [ -n "$SRV_PID" ] && kill -9 "$SRV_PID" 2>/dev/null
  app_stop
  [ -s "$SETTINGS_BACKUP" ] && cfg_write settings.json "$SETTINGS_BACKUP"
  rm -f "$SETTINGS_BACKUP"
  cfg_restore
}
server_start || { fail "server did not come up (see $RIG/server.log)"; kill "$SRV_PID" 2>/dev/null; summary; exit 1; }
curl -s -o /dev/null -X PUT "http://127.0.0.1:$PORT/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["demo"],"admin":true}'
TOKEN=$(curl -s -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { fail "could not log in to the rig server"; kill "$SRV_PID"; summary; exit 1; }
# Five tracks of three minutes or more, in a fixed order: long enough that a
# run of fast-forwards lands past what is buffered and not past the end.
N=0
for _ in $(seq 1 120); do
  curl -s -X POST "http://127.0.0.1:$PORT/api/v1/db/recent/added" -H "$J" -H "x-access-token: $TOKEN" -d '{"limit":200}' > "$OUT/tracks.json" 2>/dev/null
  N=$(python3 -c "import json,sys
try: print(sum(1 for t in json.load(open(sys.argv[1])) if ((t.get('metadata') or {}).get('duration') or 0) >= 180))
except Exception: print(0)" "$OUT/tracks.json")
  [ "$N" -ge 5 ] && break; sleep 1
done
[ "$N" -ge 5 ] || { fail "the library has fewer than five tracks of 3 min or more after the boot scan"; kill "$SRV_PID"; summary; exit 1; }
for _ in $(seq 1 60); do curl -s "http://127.0.0.1:$PORT/api/v1/db/status" | grep -q '"locked":false' && break; sleep 1; done
log "server $NAME on :$PORT (phone side http://$HOST:$PORT), user rig, $N long tracks"

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
python3 - "$OUT/tracks.json" "$OUT/queue.json" "$NAME" <<'PY'
import json,sys
tracks,dst,name=sys.argv[1:]
long=[t for t in json.load(open(tracks)) if ((t.get('metadata') or {}).get('duration') or 0) >= 180]
long.sort(key=lambda t: t['filepath'])
items=[]
for t in long[:5]:
    m=t.get('metadata') or {}; p='/'+t['filepath']
    items.append({"id":p,"title":m.get('title') or p.split('/')[-1],"album":m.get('album'),"artist":m.get('artist'),"genre":None,
                  "durationMs":int((m.get('duration') or 0)*1000) or None,
                  "extras":{"server":name,"path":p,"year":m.get('year'),"track":m.get('track'),"disc":m.get('disc'),"rating":None,"artUrl":None,
                            "bpm":None,"musicalKey":None,"bitrate":None,"sampleRate":None,"format":None,"trackTotal":None,"discTotal":None,
                            "playCount":None,"lastPlayed":None,"hash":m.get('hash'),"hasLyrics":False}})
json.dump({"version":1,"index":0,"items":items}, open(dst,'w'))
print(' | '.join(i['title'] for i in items))
PY
# Start on just_audio whatever the app's default is, with the equalizer off:
# its attach and release would only add lines the round does not read.
python3 - "$SETTINGS_BACKUP" "$OUT/settings.json" <<'PY'
import json,sys
src,dst=sys.argv[1:]
try: d=json.load(open(src))
except Exception: d={"tapBehavior":"playFromHere"}
d['media3Engine']=False; d['eqEnabled']=False; d['resumeQueue']=True
json.dump(d, open(dst,'w'))
PY
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
cfg_write servers.json "$OUT/servers.json"; cfg_write queue.json "$OUT/queue.json"
cfg_write settings.json "$OUT/settings.json"; cfg_write auto_dj.json "$OUT/auto_dj.json"
rm -f "$OUT/auto_dj.json" "$OUT/settings.json"
logcat_clear; wake; app_start
wait_for_log "\[app\] default server ready: $NAME" 40 && pass "app launched on $NAME" || { fail "app did not settle on $NAME"; save_applog launch; summary; exit 1; }
wait_for_log "\[audio\] playback engine: just_audio" 5 && pass "booted on just_audio's engine" || fail "no '[audio] playback engine: just_audio' line at boot"
sleep 10 # a PLAY key in the first seconds after a cold start is dropped
ui_dump | grep -qE '(text|content-desc)="[^"]' || { fail "no text in the accessibility dump — build with --dart-define=SMOKE_SEMANTICS=true"; save_applog launch; summary; exit 1; }

# Settings › New audio engine, from the home screen and back to it.
switch_engine() { # <media3|just_audio> → 0 once the handler says playback is on it
  local want="$1" t; t=$(now_ts)
  tap_text "Open navigation menu" || return 1
  sleep 1; tap_text "Settings" || return 1
  sleep 2; tap_text "New audio engine" || { key KEYCODE_BACK; return 1; }
  wait_for_log_after "$t" "\[audio\] playback engine → $want" 40; local r=$?
  key KEYCODE_BACK; sleep 1
  return $r
}

# ── 1. just_audio plays; the switch carries the track across ──
ensure_playing 20 && pass "just_audio: the restored queue plays" || { fail "playback did not start on just_audio"; save_applog play; summary; exit 1; }
sleep 12
IDX1=$(queue_index); P1=$(pos_ms); W1=$(date +%s)
if switch_engine media3; then
  pass "switched to the Media3 engine mid-track"
else
  fail "the switch to the Media3 engine did not complete"; save_applog switch; summary; exit 1
fi
engine_sync
[ "$(players_made)" -ge 1 ] && pass "a native player was made on the Media3 engine" || fail "no 'Media3Engine: player … on Media3' line in logcat"
wait_playing 15 && pass "still playing after the switch" || fail "playback did not resume after the switch"
IDX2=$(queue_index); P2=$(pos_ms); W2=$(date +%s)
python3 - "$P1" "$P2" "$((W2-W1))" "$IDX1" "$IDX2" <<'PY' && pass "same track, same spot (${P1} ms → ${P2} ms across the switch)" || fail "the spot moved across the switch (index $IDX1 → $IDX2, ${P1} ms → ${P2} ms)"
import sys
p1,p2,dt,i1,i2=sys.argv[1:]
p1,p2,dt=int(p1),int(p2),int(dt)
# The reload costs a second or two of playing time; it never jumps ahead.
assert i1==i2 and p1>0 and p1-3000 <= p2 <= p1+dt*1000+3000
PY
[ "$(saved_engine)" = True ] && pass "the choice is saved (media3Engine: true)" || fail "settings.json media3Engine is '$(saved_engine)', expected true"

# ── 2. the Media3 engine: transport, a stop, a relaunch ──
T=$(now_ts); media_key pause; sleep 2
is_playing && fail "Media3: still playing after PAUSE" || pass "Media3: pause"
ensure_playing 10 && pass "Media3: resume" || fail "Media3: did not resume"
T=$(now_ts); key 87; wait_for_log_after "$T" "\[play\] track 2/5" 15 && pass "Media3: next moves to track 2" || fail "Media3: no track change on NEXT"
sleep 3; PA=$(pos_ms); key 90; sleep 2; PB=$(pos_ms)
[ "$((PB-PA))" -ge 8000 ] && pass "Media3: fast-forward seeks ($PA → $PB ms)" || fail "Media3: fast-forward moved $((PB-PA)) ms"
M0=$(engine_sync; players_made)
T=$(now_ts); key 86
wait_for_log_after "$T" "\[play\] state → idle" 10 && pass "Media3: stop goes idle" || fail "Media3: no idle after STOP"
sleep 2; T=$(now_ts); media_key play
wait_for_log_after "$T" "\[play\] play on an idle player — re-seeding sources" 10 && wait_playing 20 \
  && pass "Media3: play after a stop re-seeds and plays" || fail "Media3: play after a stop did not come back"
engine_sync
[ "$(players_made)" -gt "$M0" ] && pass "Media3: the re-seed made a new native player on the engine" || fail "Media3: no new native player after the stop"
save_applog media3-transport
app_stop; sleep 2; T=$(now_ts); wake; app_start
wait_for_log_after "$T" "\[audio\] playback engine: media3" 40 && pass "a relaunch boots on the Media3 engine" || fail "the relaunch did not boot on the Media3 engine"
wait_for_log_after "$T" "\[play\] state → ready" 40 && pass "Media3: the saved queue restores" || fail "Media3: the saved queue did not load after the relaunch"
sleep 10
ensure_playing 20 && pass "Media3: plays after the relaunch" || fail "Media3: did not play after the relaunch"

# ── 3. the dead server, once per engine ──
# The shape of an outage: the handler's own lines, without the stamps, the
# titles and the counters. Two engines that behave alike print the same one.
shape() { # <since ts> → the first 22 lines: the skip, the walk's opening
  applog | awk -v s="$1" 'substr($1,1,12) >= s' \
    | grep -E "\[play\] (state →|playback error|network error|retry [0-9]|track [0-9])" \
    | sed -E 's/^[0-9:.]+ //; s/track [0-9]+\/[0-9]+: .*/track N/; s/index=[0-9]+/index=N/; s/failedSkips=[0-9]+\/[0-9]+/failedSkips=K/' \
    | head -22
}
outage_round() { # <label>
  local label="$1" t0
  # From the top of the queue, so both engines walk the same road.
  for _ in 1 2 3 4 5; do key 88; sleep 0.8; done
  ensure_playing 20 || { fail "$label: not playing before the outage"; return; }
  sleep 5
  [ "$(queue_index)" = 0 ] || log "$label: outage starts at index $(queue_index), not 0"
  t0=$(now_ts)
  server_stop
  # NEXT, not a seek within the track: track 2 has to be fetched from
  # nothing, so the load fails in seconds with the skip's seek unanswered.
  # A seek inside the playing track can go on for a minute first, on audio
  # that was already in transit when the server died — by how much depends on
  # the connection, not on the engine (15 s to 68 s seen, on both).
  key 87
  wait_for_log_after "$t0" "\[play\] playback error \(\(0\) Source error\) index=1" 40 \
    && pass "$label: the dead server surfaces as '(0) Source error' ($(secs_between "$t0" "$(ts_after "$t0" "\[play\] playback error")") s after it went)" \
    || fail "$label: no '(0) Source error' on track 2 within 40 s of the server going"
  wait_for_log_after "$t0" "retry 3 did not load: \(0\) Source error" 60 \
    && pass "$label: three retries, each failing as a source error" || fail "$label: the three retries did not run to the end (see outage-$label.log)"
  wait_for_log_after "$t0" "\[play\] track 3/5" 30 \
    && pass "$label: the walk moved on to the next track" || fail "$label: the walk never skipped (see outage-$label.log)"
  sleep 9 # the skipped-to track's own failure
  applog | awk -v s="$t0" 'substr($1,1,12) >= s' > "$OUT/outage-$label.log"
  shape "$t0" > "$OUT/outage-$label.shape"
  if grep -q "Loading interrupted" "$OUT/outage-$label.log"; then
    fail "$label: a retry read 'Loading interrupted' — the player is wedged (see outage-$label.log)"
  else
    pass "$label: no retry was interrupted"
  fi
  server_start || { fail "$label: the server did not come back"; return; }
  log "server back"
  # The walk either lands on a track that loads now, or has run off the end
  # and stopped; a PLAY then re-seeds.
  wait_playing 25 || ensure_playing 25
  is_playing && pass "$label: playing again after the server returned" || fail "$label: no playback after the server returned"
}
outage_round media3
engine_sync
ALIVE=$(players_alive)
[ "$ALIVE" = 1 ] && pass "Media3: every native player the outage made was released but the live one ($(players_made) made in all)" \
  || fail "Media3: $ALIVE native players alive after the outage — expected exactly one (see engine.log)"

if switch_engine just_audio; then pass "switched back to just_audio mid-track"; else fail "the switch back to just_audio did not complete"; fi
wait_playing 15 && pass "still playing after the switch back" || fail "playback did not resume after the switch back"
[ "$(saved_engine)" = False ] && pass "the choice is saved (media3Engine: false)" || fail "settings.json media3Engine is '$(saved_engine)', expected false"
engine_sync
ALIVE=$(players_alive); MADE=$(players_made)
[ "$ALIVE" = 0 ] && pass "no Media3 player outlived the switch back" || fail "$ALIVE Media3 players still alive after the switch back (see engine.log)"
outage_round just_audio
engine_sync
[ "$(players_made)" = "$MADE" ] && pass "just_audio's round made no player on the Media3 engine" || fail "a Media3 player was made while the choice was just_audio"

if [ -s "$OUT/outage-media3.shape" ] && diff "$OUT/outage-just_audio.shape" "$OUT/outage-media3.shape" > "$OUT/outage-shape.diff"; then
  pass "the two engines print the same outage, line for line ($(wc -l < "$OUT/outage-media3.shape" | tr -d ' ') lines)"
else
  fail "the engines' outage logs differ (see outage-shape.diff: just_audio < > media3)"
fi
save_applog end
summary
