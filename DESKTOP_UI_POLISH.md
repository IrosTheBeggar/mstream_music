# Desktop UI polish — working list

Design ideas gathered from the state of the art in desktop music players
(Harmonoid, Plexamp, Feishin, Spotube, Cider, Spotify) and mapped onto this
app. Worked ONE item at a time, with a look at the running build between each
— batched visual changes can't be judged piecewise.

Companion doc: `DESKTOP_PORT_PLAN.md` (platform/feature feasibility).

## Status

| # | Item | Status |
|---|------|--------|
| 1 | Custom title bar (hide native chrome, app-drawn caption) | **Skipped** — keeping native chrome |
| 2 | Hover affordances (theme hoverColor + album-card lift) | **Done** |
| 3 | Right-click context menus mirroring the ⋮ menus | Pending — oldest open item |
| 4 | Slim seek line | **Done → superseded** by the waveform seek bar (see below) |
| 5 | Album-card polish (240px tiles, resting depth, type hierarchy) | **Done** |
| 6 | Art-adaptive accent color (palette from playing album) | **Built then reverted** — didn't land; not wanted |
| 7 | Full-screen Now Playing view — visualizer as the live backdrop | **Done** — the flagship (see below) |
| 8 | Synced lyrics pane (lyrics shipped in v0.30, surface on desktop) | **Done** — landed inside #7 |
| 9 | Home dashboard landing (recently played / added / playlists shelves) | Pending |
| 10 | Ctrl+K global search / command palette | Pending |
| 11 | Windows SMTC (media overlay w/ art + transport, `smtc_windows`) | Pending — Windows-side |
| 12 | Mini player (small always-on-top window) | Pending — bigger lift |
| 13 | Queue redesign (now/up-next grouping) | **Done** — "Queue" header + flat rows + full-height bar card |
| 14 | Accent/theme customization | Pending — `VelvetPalette.withAccent` already exists |

## Delivered beyond the original list

- **Waveform seek bar** — the seek line became a SoundCloud-style waveform fed
  by the server's `/api/v1/db/waveform` endpoint (the web app's own source),
  per-track/per-server with a peaks cache; plain-line fallback when absent.
- **Colour system** — monotone → tonal zoning → the web-app "flat field": dark
  chrome frame (sidebar + bar on `appBarBg`) with two `border2` structural
  hairlines, one flat content field shared by browser + queue, boxed browse
  rows rising to the `card` tone, flat queue rows.
- **Bar / now-playing architecture** — see below.
- **Now Playing extras** — up-next peek, in-place rating, FLAC/44.1 kHz-style
  fidelity badge, and Tier-1 party mode (fullscreen + hold-to-unlock, optional
  4-digit PIN, `WakeGuard` to keep the display awake).
- **macOS enablement** — the `macos/` runner, SPM-only deps, darwin server-path
  fix, app data moved out of `~/Documents` (TCC), and the visualizer's
  real-audio path via the `viz_decoder` sidecar + backdrop render mode.

## The bar / queue / Now Playing architecture (current)

The seek line started as a thin strip inside the bar (#4); it grew into the
whole layout below.

- **Now Playing bar** (120px): top pad · elapsed/duration row · waveform band ·
  the controls row. The waveform strip floats on the shell's root `Stack`
  straddling the content/bar boundary (`Positioned` in `_DesktopShellState`),
  spanning sidebar → the now-playing card. Thumb on hover only.
- **Now-playing card** owns the bar's full-height right corner (88px art +
  title/artist/album) and stays put whether the queue is open or closed. Its
  album art is the door to the full-screen Now Playing (hover → expand glyph);
  a folded queue glyph in its corner toggles the queue.
- **Queue column** reads a "Queue" header (carrying clear · save/download/share
  · close) → the track list. It shares the content field with the browser (no
  divider), web-app style.
- **Full-screen Now Playing** (#7) covers the whole shell: blurred album art or
  the live shader visualizer as backdrop (corner toggle, no reflow between
  states), the shared waveform + transport, a synced-lyrics pane (#8), up next,
  rating + fidelity badge, and the party-mode lock.

## Ground rules learned

- One visual change per verdict; keep each independently revertable.
- Judge feel/perf on RELEASE builds only (debug JIT lies about jank).
- The hover-play button on album cards needs a side-effect-free album-songs
  fetch (the current API call drives browse navigation) — follow-up for #3
  or whenever cards grow inline actions.
