# Play history

What the scripted round proves (`smoke/android/play-history.sh`, 4 min, an
emulator or a phone with the `.plus.dev` build): a fresh local mStream 6.27+
with the demo library and one account; the app restores a three-track queue
and plays it under adb. Each session must land on the phone's own record AND
on the server, with the outcome the player saw and the start time the phone
saw:

| Step | Phone log | Server |
|---|---|---|
| skip at 35 s | `[history] skipped play 35s/…` then `[sync] stats-rig: 1 accepted` | `outcome: skipped, counted: true` |
| skip at 10 s | `[history] skipped no-play` then `1 accepted` | `skipped, counted: false` (the server decides, the app still reports) |
| airplane mode, skip at 35 s | `[history] skipped play` then `[sync] stats-rig unreachable`; `play_outbox.json` holds it | nothing yet |
| airplane off | `[sync] stats-rig: 1 accepted` within 45 s | the row's `startedAt` is the phone's play time, not the sync time |
| force-kill at 20 s, relaunch | `[history] recovered a session cut short by a kill` then `1 accepted` | `stopped, counted: false` |
| end | `play_history.jsonl` has 4 lines; `play_stats.json` ring 4, 2 counted | `stats/history` lists 4 plays from `mstream-music`; `stats/tracks` counts the first track |
| Listening page | home › Listening: "This phone" renders; the server chip renders from the Stats API (no "did not answer") | — |

Run it:

```bash
smoke/android/play-history.sh                       # emulator: the server binds 127.0.0.1, the phone dials 10.0.2.2
SMOKE_HOST=192.168.1.20 smoke/android/play-history.sh   # a real phone: the Mac's LAN address, server binds 0.0.0.0
SMOKE_SRC=~/code/mstream SMOKE_MUSIC=~/code/mstream-demo-music   # defaults
```

It backs up and restores `servers.json` / `queue.json`, deletes the phone's
play-history files first (they are the thing under test), boots its own
server in `smoke/out/<run>/srv/` and kills it on exit.

## What the script cannot see — do by hand once per release

1. **A real listen.** Play an album for twenty minutes with the screen off.
   Home › Listening › This phone: the plays are there with the right times,
   the streak tile moved, the hour bar has today's hour. Switch the scope to
   the server: the same plays, now with the client column ("mstream-music")
   — and any plays from the web player on the same account.
2. **A peer's track.** With a federated peer paired, play one of its tracks.
   The row on the phone says "via <peer>"; on the parent's web Stats page
   the play appears under Peers, never on the peer's own server. The
   parent completes the row from the peer's metadata within a minute
   (title/artist/duration), and the phone's Song Info shows "N plays on
   <parent>" for it.
3. **Kill in the car.** Start an album over Android Auto or CarPlay, pull the
   key. Next launch: the cut session is on the Listening page as "Stopped
   at m:ss", and after a moment on the server.
4. **Settings.** Settings › Listening history: turn "Send plays to your
   servers" off — the "waiting to be sent" line drops to "Everything is
   synced" and nothing reaches the server; back on — the next play syncs.
   Turn "Keep listening history" off — the page empties and the files are
   gone (Settings shows the size); the server keeps its record. "Clear
   listening history" asks first.
5. **Song Info.** Long-press a played track › Info: "N plays on <server> ·
   last 3 min ago" and "N plays on this phone" both present and agreeing.
6. **An old server** (6.26): Listening shows the phone's plays on it with the
   "no listening stats yet" line; nothing is posted; no error.

Evidence: the Listening page screenshots for both scopes, Diagnostics › Share
for the `[history]` / `[sync]` lines, and the server's `stats/history` answer.
