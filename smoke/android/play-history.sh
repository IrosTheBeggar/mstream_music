#!/usr/bin/env bash
# Play history, end to end: a fresh local mStream (6.27+, Stats API v2) with
# the demo library and one account; the app restores a three-track queue and
# plays it under adb — a skip at 35 s (a counted play), a skip at 10 s (logged,
# not counted), a play in airplane mode (held in the outbox, posted when the
# network returns, at its own start time), and a force-kill mid-track (the
# checkpoint closes it as `stopped` on the next launch). Every session must
# land on the phone's own record AND on the server, and the Listening page
# must render both scopes.
#
#   SMOKE_SRC    mStream checkout to boot (default ~/code/mstream); must report
#                features.stats = 2 (6.27+)
#   SMOKE_MUSIC  library root (default ~/code/mstream-demo-music)
#   SMOKE_HOST   how the phone reaches this Mac: 10.0.2.2 on the emulator
#                (default), the Mac's LAN address on a real phone
#   SMOKE_PORT   the server's port (default 3171)
source "$(dirname "$0")/../lib.sh"; pick_device
SRC="${SMOKE_SRC:-$HOME/code/mstream}"
MUSIC="${SMOKE_MUSIC:-$HOME/code/mstream-demo-music}"
HOST="${SMOKE_HOST:-10.0.2.2}"
PORT="${SMOKE_PORT:-3171}"
NAME="stats-rig"
J='Content-Type: application/json'
[ -f "$SRC/cli-boot-wrapper.js" ] || { echo "no mStream checkout at $SRC (SMOKE_SRC)"; exit 2; }
[ -d "$MUSIC" ] || { echo "no library at $MUSIC (SMOKE_MUSIC)"; exit 2; }

media_next() { adbx shell input keyevent 87; log "media key: next"; }
hist_files() { adbx shell "run-as $PKG ls app_flutter" 2>/dev/null | tr -d '\r' | grep -E '^play_' | tr '\n' ' '; }
hist_clear() { adbx shell "run-as $PKG sh -c 'rm -f app_flutter/play_history.jsonl app_flutter/play_stats.json app_flutter/play_outbox.json app_flutter/play_session.json'" 2>/dev/null; }
ring_lines() { adbx shell "run-as $PKG cat app_flutter/play_history.jsonl" 2>/dev/null | grep -c '"id"'; }
# Tap the centre of the first accessibility node whose text / description
# contains <needle> (Flutter builds its semantics tree for the dump).
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
ui_has() { ui_dump | grep -q "$1"; }
api() { # <method> <path> [json body] → body
  if [ $# -ge 3 ]; then curl -s -X "$1" "http://127.0.0.1:$PORT$2" -H "$J" -H "x-access-token: $TOKEN" -d "$3"
  else curl -s -X "$1" "http://127.0.0.1:$PORT$2" -H "$J" -H "x-access-token: $TOKEN"; fi
}

# ── the server ──
RIG="$OUT/srv"; mkdir -p "$RIG/db" "$RIG/art" "$RIG/logs"
ADDR=127.0.0.1; [ "$HOST" = 10.0.2.2 ] || ADDR=0.0.0.0
python3 - "$RIG" "$PORT" "$ADDR" "$MUSIC" <<'PY'
import json,sys
rig,port,addr,music=sys.argv[1:]
json.dump({"port":int(port),"address":addr,"dlna":{"mode":"disabled"},"folders":{"demo":{"root":music}},
           "storage":{"albumArtDirectory":rig+"/art","dbDirectory":rig+"/db","logsDirectory":rig+"/logs"},
           "scanOptions":{"bootScanDelay":1,"scanInterval":0,"autoAlbumArt":False},
           "stats":{"playThresholdMs":30000,"playThresholdFraction":0.5,"retentionMonths":24}}, open(rig+"/config.json","w"))
PY
# A leftover server on the port (a previous run's, or the user's own) would
# answer for ours and fail the capability check for the wrong reason.
if lsof -ti "tcp:$PORT" -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT is in use — free it or set SMOKE_PORT"; exit 2; fi
# exec, so SRV_PID is node itself and the exit trap really kills it.
(cd "$SRC" && exec env NODE_ENV=test node cli-boot-wrapper.js -j "$RIG/config.json" > "$RIG/server.log" 2>&1) &
SRV_PID=$!
cleanup() { kill "$SRV_PID" 2>/dev/null; cfg_restore; }
for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$PORT/api/" && break; sleep 1; done
curl -s -o /dev/null "http://127.0.0.1:$PORT/api/" || { fail "server did not come up (see $RIG/server.log)"; kill "$SRV_PID" 2>/dev/null; summary; exit 1; }
curl -s -o /dev/null -X PUT "http://127.0.0.1:$PORT/api/v1/admin/users" -H "$J" -d '{"username":"rig","password":"rigpw","vpaths":["demo"],"admin":true}'
TOKEN=$(curl -s -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" -H "$J" -d '{"username":"rig","password":"rigpw"}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { fail "could not log in to the rig server"; kill "$SRV_PID"; summary; exit 1; }
STATS=$(api GET /api/ | python3 -c "import sys,json; print(json.load(sys.stdin).get('features',{}).get('stats',''))")
[ "$STATS" = 2 ] && pass "server advertises Stats API v2 (features.stats = 2)" || { fail "server at $SRC lacks Stats API v2 (features.stats = '$STATS')"; kill "$SRV_PID"; summary; exit 1; }
# three tracks, with their metadata, for the queue — the boot scan has to
# have reached them first (bootScanDelay 1 s, then the library).
N=0
for _ in $(seq 1 120); do
  api POST /api/v1/db/recent/added '{"limit":5}' > "$OUT/tracks.json" 2>/dev/null
  N=$(python3 -c "import json,sys
try: print(len(json.load(open(sys.argv[1]))))
except Exception: print(0)" "$OUT/tracks.json")
  [ "$N" -ge 3 ] && break; sleep 1
done
[ "$N" -ge 5 ] || { fail "the library has fewer than 5 tracks after the boot scan"; kill "$SRV_PID"; summary; exit 1; }
for _ in $(seq 1 60); do curl -s "http://127.0.0.1:$PORT/api/v1/db/status" | grep -q '"locked":false' && break; sleep 1; done
log "server $NAME on :$PORT (phone side http://$HOST:$PORT), user rig, $N tracks"

# ── the phone ──
cfg_backup; trap cleanup EXIT
hist_clear
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
items=[]
for t in json.load(open(tracks))[:5]:
    m=t.get('metadata') or {}; p='/'+t['filepath']
    items.append({"id":p,"title":m.get('title') or p.split('/')[-1],"album":m.get('album'),"artist":m.get('artist'),"genre":None,
                  "durationMs":int((m.get('duration') or 0)*1000) or None,
                  "extras":{"server":name,"path":p,"year":m.get('year'),"track":m.get('track'),"disc":m.get('disc'),"rating":None,"artUrl":None,
                            "bpm":None,"musicalKey":None,"bitrate":None,"sampleRate":None,"format":None,"trackTotal":None,"discTotal":None,
                            "playCount":None,"lastPlayed":None,"hash":m.get('hash'),"hasLyrics":False}})
json.dump({"version":1,"index":0,"items":items}, open(dst,'w'))
print(' | '.join(i['title'] for i in items))
PY
app_stop; cfg_write servers.json "$OUT/servers.json"; cfg_write queue.json "$OUT/queue.json"
logcat_clear; wake; app_start
wait_for_log "\[app\] default server ready: $NAME" 40 && pass "app launched on $NAME" || { fail "app did not settle on $NAME"; save_applog launch; summary; exit 1; }
sleep 4
cfg_read servers.json | python3 -c "import sys,json; sys.exit(0 if any(s.get('localname')=='$NAME' and s.get('statsVersion')==2 for s in json.load(sys.stdin)) else 1)" \
  && pass "statsVersion 2 learned and persisted for $NAME" || fail "statsVersion not persisted (servers.json)"

# ── 1. a skip after 35 s: a counted play, posted at once ──
T1=$(now_ts); ensure_playing 20 || { fail "playback did not start from the restored queue"; save_applog play; summary; exit 1; }
sleep 35; media_next; T2=$(now_ts)
# ── 2. straight on: a skip after 10 s (logged, not counted, still posted) ──
sleep 10; media_next; T2b=$(now_ts)
wait_for_log_after "$T1" "\[history\] skipped play (3[0-9]|4[0-9])s/" 10 && pass "35 s skip closed as a counted play" || fail "no counted-play line after the 35 s skip"
wait_for_log_after "$T2" "\[history\] skipped no-play" 10 && pass "10 s skip closed as not counted" || fail "no not-counted line after the 10 s skip"
wait_for_log_after "$T1" "\[sync\] $NAME: 1 accepted" 30 && pass "the counted play was posted and accepted" || fail "the counted play was not posted (see phase1 log)"
wait_for_log_after "$T2" "\[sync\] $NAME: 1 accepted" 30 && pass "the uncounted play was posted too (the server decides)" || fail "the uncounted play was not posted (see phase1 log)"
shot after-skips

# ── 3. airplane mode: the play waits in the outbox and drains on reconnect at its own time ──
ensure_playing 10 || fail "playback stopped before the airplane phase"
airplane on; sleep 3
T3=$(now_ts); sleep 35; media_next
wait_for_log_after "$T3" "\[history\] skipped play" 10 && pass "offline skip recorded on the phone" || fail "no history line for the offline skip"
if wait_for_log_after "$T3" "\[sync\] $NAME unreachable" 25; then pass "outbox held the play while offline"; else fail "no unreachable line while offline"; fi
PENDING=$(adbx shell "run-as $PKG cat app_flutter/play_outbox.json" 2>/dev/null | grep -c '"id"')
[ "$PENDING" -ge 1 ] && pass "play_outbox.json holds $PENDING play(s)" || fail "play_outbox.json is empty while offline"
airplane off; T4=$(now_ts)
wait_for_log_after "$T4" "\[sync\] $NAME: 1 accepted" 45 && pass "outbox drained after the network returned" || fail "outbox did not drain after reconnect"

# ── 4. force-kill mid-track: the checkpoint closes it as stopped on relaunch ──
ensure_playing 10 || fail "playback stopped before the kill phase"
sleep 20; save_applog phase1; app_stop; sleep 2; logcat_clear; wake; app_start
wait_for_log "\[history\] recovered a session cut short by a kill" 40 && pass "killed session recovered as stopped" || fail "no recovery line after the kill"
wait_for_log "\[sync\] $NAME: 1 accepted" 40 && pass "the recovered session was posted" || fail "the recovered session was not posted"

# ── the two records agree ──
LINES=$(ring_lines)
[ "$LINES" = 4 ] && pass "phone ring holds 4 events" || fail "phone ring holds $LINES events (expected 4): $(hist_files)"
api GET "/api/v1/stats/history?limit=10" > "$OUT/server-history.json"
python3 - "$OUT/server-history.json" "$OUT/tracks.json" <<'PY' && pass "server history: 4 plays from mstream-music, outcomes and counted flags as played" || fail "server history disagrees (see $OUT/server-history.json)"
import json,sys
h=json.load(open(sys.argv[1])).get('items',[])
ours=[i for i in h if str(i.get('client','')).startswith('mstream-music')]
assert len(ours)==4, f'{len(ours)} plays from the app'
oldest_first=list(reversed(ours))
outcomes=[i['outcome'] for i in oldest_first]; counted=[i['counted'] for i in oldest_first]
assert outcomes==['skipped','skipped','skipped','stopped'], outcomes
assert counted==[True,False,True,False], counted
assert all(i.get('source')=='manual' for i in ours), 'source'
PY
python3 - "$OUT/server-history.json" "$T3" <<'PY' && pass "the offline play kept its own start time" || fail "the offline play's start time drifted (posted-time instead of play-time?)"
import json,sys,datetime
h=json.load(open(sys.argv[1])).get('items',[])
ours=[i for i in h if str(i.get('client','')).startswith('mstream-music')]
offline=list(reversed(ours))[2]
t=datetime.datetime.fromisoformat(offline['startedAt'].replace('Z','+00:00'))
hms=sys.argv[2].split('.')[0]
# the phone's clock at the offline play, today, in its own zone: within 5 minutes of the server row
now=datetime.datetime.now().astimezone(); ph=now.replace(hour=int(hms[0:2]),minute=int(hms[3:5]),second=int(hms[6:8]),microsecond=0)
diff=abs((t.astimezone()-ph).total_seconds())
assert diff < 300, f'{diff}s apart'
PY
# per-track counters on both sides for the first track
FIRST=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[0]['filepath'])" "$OUT/tracks.json")
api POST /api/v1/stats/tracks "{\"filePaths\":[\"$FIRST\"]}" | python3 -c "import sys,json; it=json.load(sys.stdin)['items']; assert it and it[0]['plays']>=1, it" \
  && pass "server counters: the first track has a play" || fail "server counters missing for the first track"
adbx shell "run-as $PKG cat app_flutter/play_stats.json" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ring']==4 and sum(t['n'] for t in d['tracks'])==2, d['ring']" \
  && pass "phone aggregates: ring 4, 2 counted plays" || fail "phone aggregates disagree"

# ── the Listening page, both scopes ──
key KEYCODE_BACK; sleep 1
if ! ui_dump | grep -q 'text="[^"]'; then
  skip "no text in the accessibility dump — build with --dart-define=SMOKE_SEMANTICS=true for the page checks"
elif tap_text "Listening"; then
  sleep 4; shot listening-device
  ui_has "This phone" && pass "Listening page: device scope rendered" || fail "Listening page did not render the device scope"
  if tap_text "$NAME"; then
    sleep 5; shot listening-server
    ui_has "$NAME" && ! ui_has "did not answer" && pass "Listening page: server scope rendered from the Stats API" || fail "Listening page server scope fell back or failed"
  else fail "no server chip on the Listening page"; fi
  key KEYCODE_BACK
else
  fail "no Listening node on the home screen"
fi
save_applog phase2
summary
