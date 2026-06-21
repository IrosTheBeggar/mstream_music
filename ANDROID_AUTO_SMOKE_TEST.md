# Android Auto — DHU Smoke Test (branch `claude/android-auto-phase0`, full flavor)

Generated for the final smoke test of the Android Auto feature. Target: **full** flavor
(`mstream.music.plus`) on the phone, driven through the Desktop Head Unit (DHU).
Uncommitted working doc — delete when done.

## Already set up for you
- Device connected: `192.168.1.141:39873`
- Fresh **full** APK (v0.27.0, HEAD `0afa288`) built + installed
- DHU port-forward live: `adb forward tcp:5277 tcp:5277`
- DHU exe present: `%LOCALAPPDATA%\Android\Sdk\extras\google\auto\desktop-head-unit.exe`
- Headless cold-bind verified: service boots clean (`art authority: mstream.music.plus.art`, `mStream v0.27.0 started`, no crash)

## To start the DHU (manual, on your side)
1. Phone → Android Auto app → Settings → tap the version 10× to unlock Developer mode.
2. Android Auto dev menu → **Start head unit server**.
3. Run `desktop-head-unit.exe` (forward is already in place). The car home screen appears.
4. Open **mStream** from the DHU app launcher.

## Run order (happy paths first, destructive last)
1. Core browse + playback → 2. Album art → 3. Large library + pagination →
4. Search + voice → 5. Shuffle/Resume/Files → 6. Repeat/shuffle + persistence →
7. Resilience/edge (breaks state — do last). Keep the DHU session open across sections;
**force-stop the app** before any step whose premise is "cold/headless bind".

---

## 1. Core browse + playback
- [ ] **Open mStream in DHU** → root rows: Shuffle All, Recently Added, Playlists, Albums, Artists, Files. >4 browsable tabs auto-overflow into a **"More"** tab. *Fail: "Open mStream on your phone" notice (no server) / crash.*
- [ ] **Tap "Shuffle All"** → now-playing appears, a random track plays, white status icon shows. *Fail: silence >15s / returns to list / no 2nd track queued.*
- [ ] **Albums** → ≤200: album art **grid** (name + "artist · year"); >200: A–Z **letter index** (text rows w/ category icon, '#' last). *Fail: list instead of grid; blank/broken tiles; '#' not last.*
- [ ] **Drill a letter → an album → tap track 4 (not 1)** → whole album queues, plays **from track 4**; next/prev traverse album. *Fail: starts at track 1; only 1 track; filenames instead of titles.*
- [ ] **Now-playing**: title/artist/album + cover art; **next** advances, **previous** returns. *Fail: blank art; empty metadata; stuck on browse.*
- [ ] **Pause / play / scrub seek bar** → toggles + jumps correctly, status-bar controls mirror. *Fail: no toggle; seek snaps back; position frozen.*
- [ ] **Artists → artist → album → track** → artists = text list; artist's albums = **grid**; track plays whole album from that point. *Fail: artist's albums render as list; starts at track 1.*
- [ ] **Playlists → playlist → mid track** → names list; tracks w/ titles; plays playlist from that point.
- [ ] **Recently Added** → list of recent tracks (≤100), playable.
- [ ] **Files → subfolder → audio file** → folders (browsable) then files (playable); tap file plays its folder from that point. Empty folder → "Nothing here".
- [ ] **Status icon**: monochrome white music note in DHU status bar + phone notification (not a white square / color launcher icon).

## 2. Album art (content:// provider)
- [ ] **Confirm full build**: `adb shell pm list packages | grep mstream` → `mstream.music.plus` (NOT `mstream.music`). Provider authority `mstream.music.plus.art`.
- [ ] **Album grid covers render** (brief placeholder → fill on first visit, instant on re-entry). *Fail: permanent blank/grey/error tiles → check `adb shell run-as mstream.music.plus ls cache/auto_art`.*
- [ ] **Track-list row thumbnails** show the album cover.
- [ ] **Artists = text rows (no art) — correct.** Drilling an artist → album **grid** with covers.
- [ ] **Search hits**: song + album hits show covers; artist hits text-only.
- [ ] **Now-playing + notification** show the large cover.
- [ ] **Cache**: re-entry instant; after `rm -rf cache/auto_art` the placeholder→fill returns.

## 3. Large library A–Z buckets + pagination
*(Needs a server with >200 albums AND >200 artists. Force-stop first for a cold bind.)*
- [ ] **Albums** → A–Z letter index (category-list rows, '#' last, no "Show more" — Albums/Artists bucket, never paginate).
- [ ] **Drill a letter <200** → album **grid** of that letter's albums.
- [ ] **Article strip**: "The Wall" appears under **W**, not T; displayed title keeps "The".
- [ ] **Sub-bucketing**: a letter with >200 → second-level 2-char index (SA, SE, ST…), max depth 3.
- [ ] **Artists** → same index; leaves = text list; "The Beatles" under **B**.
- [ ] **PAGINATION ("Show more")**: open a **Files folder with >200 tracks** (or a >200-track playlist) → first 200 + a **"Show more"** row → tap → next 200, etc. *Fail: silent truncation at 200; "Show more" reloads page 0 / empty; appears on ≤200.*
- [ ] **List cache**: re-drilling the same letter within ~30s is instant (no full re-fetch).
- [ ] **Small-library regression** (≤200 server): Albums opens straight to a grid, no A–Z index, no "Show more".

## 4. Search + Google Assistant voice
- [ ] **Search icon** in mStream's app bar → type a term matching a song + album + artist.
- [ ] **Results order**: playable **songs first**, then browsable **albums**, then **artists**. Raw files excluded.
- [ ] **Tap first song hit** → plays it, remaining title hits queued behind.
- [ ] **Tap an album / artist row** → **navigates in** (does not play).
- [ ] **Voice "Play \<album\> on mStream"** → plays (precedence: matching song › first named album › first named artist's first named album; "Singles"/null buckets skipped).
- [ ] **Voice artist / song** variants.
- [ ] **Empty query** → empty screen (no crash); **garbage query** → "No results / Try a different search".
- [ ] **Garbage voice** → no playback, no crash, current playback untouched.

## 5. Shuffle All / Resume / Files
- [ ] **Shuffle All from clean queue** → plays + a 2nd track pre-queued; real title + art.
- [ ] **Keeps topping up**: skip Next repeatedly → never runs out (new random appended near end).
- [ ] **Re-tap Shuffle All (warm queue)** → clears + restarts fresh (not append).
- [ ] **Resume setup**: play a few tracks, pause, force-stop (Resume-queue ON) → `queue.json` written.
- [ ] **Resume entry** on the Android-11 recent/resume shelf: one playable entry w/ last track's metadata + art. (Empty queue → no entry, correct.)
- [ ] **Tap Resume** → resumes the restored queue from its saved index/position; next/prev work across it.
- [ ] **Files**: walk folders → subfolders → tracks; tap 3rd track → plays folder from there (prev→2,1; next→4,5).
- [ ] **Path identity**: the Auto Files path/track matches the in-app File Explorer byte-for-byte.

## 6. Shuffle / Repeat (true repeat-one) + persistence
*(Use the in-app player panel; DHU mirrors the transport state.)*
- [ ] **Cycle repeat** none → **all** (plain repeat, amber) → **one** (`repeat_one` "1" glyph, amber) → **none**. DHU indicator matches each (one ≠ all).
- [ ] **TRUE repeat-one on natural end**: set repeat_one, seek near end, let it end → **same track restarts at 0:00** (not next). *Fail: advances to next track (old whole-list bug).*
- [ ] **Explicit Next under repeat-one** → still **advances** (only natural end replays).
- [ ] **Repeat-all** → last track ends → wraps to track 1.
- [ ] **Shuffle on/off** → non-sequential order; DHU shuffle indicator stays in sync.
- [ ] **Persistence**: set repeat_one + queue → force-stop → relaunch → reopens **paused**, icon already `repeat_one`; and natural end **replays** (backend state restored, not just the icon).
- [ ] **Repeat-all + shuffle** also survive restart.
- [ ] **Gating**: turn OFF "Resume queue on launch" → kill → relaunch → nothing restored, repeat back to none.

## 7. Resilience / edge cases (DESTRUCTIVE — do last, restore between)
- [ ] **Empty folder / empty playlist** → "Nothing here / This list is empty" (not blank).
- [ ] **No-hit search** → "No results / Try a different search".
- [ ] **Offline browse**: `adb shell cmd connectivity airplane-mode enable`, tap Albums → within ~15s "Couldn't load / **Check your connection** and try again". Then **disable airplane mode**, retap → recovers.
- [ ] **Server-error vs offline** (network UP, expire/invalid token): 5xx → "Server error / **Open mStream on your phone**"; 401/403 → "Sign in again / Open mStream on your phone". *Fail: a reachable-but-erroring server says "Check your connection".*
- [ ] **No server configured** (remove servers + force-stop) → root "Open mStream on your phone / Add a server there to browse it here".
- [ ] **Cold headless bind**: force-stop, open from DHU → queue restored **PAUSED**, **no autoplay**. (`adb logcat -s flutter` shows restore w/o `[play] play`.)
- [ ] **Shuffle All vs dead server** (black-hole host or drop network at tap) → bails within ~15s, **no hang/ANR**, DHU stays responsive.
- [ ] **Stale-id no-op**: browse an album → remove/rename that server → tap a track → silent no-op (logcat `[auto] play: server … no longer configured — stale id`), re-open node → "Couldn't load". *Fail: plays from a wrong same-named server.*

---

## Optional (not required for sign-off)
- **Play flavor on Auto** — already authority-verified this session (`mstream.music.art`); a full pass would install the `play` APK side-by-side, add a server to it, and confirm browse/art/playback + that `InsecureTls.applyArtTls` is a no-op (self-signed covers stay blank in play). Needs its own server config.
- **getMediaItem path**, **root content-style negotiation** (`supportedKey`), **artist >200-albums grid "Show more"**, **play() start-at-0 fallback on a reordered container**, **now-playing art 384px cap** — edge surfaces the review flagged as untested; low priority.
