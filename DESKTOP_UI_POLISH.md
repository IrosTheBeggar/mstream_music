# Desktop UI polish — working list

Design ideas gathered from the state of the art in desktop music players
(Harmonoid, Plexamp, Feishin, Spotube, Cider, Spotify) and mapped onto this
app. Worked ONE item at a time, with a look at the running build between each
— batched visual changes can't be judged piecewise.

Companion doc: `DESKTOP_PORT_PLAN.md` (platform/feature feasibility).

## Status

| # | Item | Status |
|---|------|--------|
| 1 | Custom title bar (hide native chrome, app-drawn caption) | **Done (macOS)** — un-skipped by the Slate redesign: `TitleBarStyle.hidden` + app-drawn black band (`_WindowTitleBar`) carrying the wordmark, native traffic lights floating over it, drag + double-click-zoom via `DragToMoveArea`. Windows/Linux keep native chrome (sidebar keeps the wordmark there) |
| 2 | Hover affordances (theme hoverColor + album-card lift) | **Done** |
| 3 | Right-click context menus mirroring the ⋮ menus | Pending — oldest open item |
| 4 | Slim seek line | **Done → superseded** by the waveform seek bar (see below) |
| 5 | Album-card polish (240px tiles, resting depth, type hierarchy) | **Done** |
| 6 | Art-adaptive accent color (palette from playing album) | **Built then reverted** — didn't land; not wanted |
| 7 | Full-screen Now Playing view — visualizer as the live backdrop | **Done** — the flagship (see below) |
| 8 | Synced lyrics pane (lyrics shipped in v0.30, surface on desktop) | **Done** — landed inside #7 |
| 9 | Home dashboard landing (recently played / added / playlists shelves) | Pending |
| 10 | Ctrl+K global search / command palette | **Done** — reframed as a full search page: ⌘K/Ctrl+K (toggle) + the sidebar Search tile open a dedicated page with organized results (artist tiles · album card shelf · song/lyric/file rows, lyric matches show their snippet). Browse's local filter moved to ⌘F. |
| 11 | Windows SMTC (media overlay w/ art + transport, `smtc_windows`) | Pending — Windows-side |
| 12 | Mini player (small always-on-top window) | Pending — bigger lift |
| 13 | Queue redesign (now/up-next grouping) | **Done** — "Queue" header + flat rows + full-height bar card |
| 14 | Accent/theme customization | **Done** (row was stale) — Settings > Accent color opens `AccentColorSheet` (preset swatches + custom HSV, writes `setAccentColor`, `withAccent` re-derives the accent-keyed shades across every theme), and the theme picker carries the full set incl. the desktop-only Onyx/Graphite frames |
| 15 | Configurable keyboard shortcuts (parity with the web player's keymap modal) | **Done** — Settings > Keyboard Shortcuts: rebind by pressing a key, clear/restore per action, master toggle; adds the web player's J/L, K and 0–9 actions |

## Delivered beyond the original list

- **Waveform seek bar** — the seek line became a SoundCloud-style waveform fed
  by the server's `/api/v1/db/waveform` endpoint (the web app's own source),
  per-track/per-server with a peaks cache; plain-line fallback when absent.
- **Colour system** — monotone → tonal zoning → the web-app "flat field": dark
  chrome frame with `border2` structural hairlines, one flat content field
  shared by browser + queue, boxed browse rows rising to the `card` tone, flat
  queue rows. Superseded in tone by the Slate three-tone scheme (below): the
  frame is now title bar + bar on `appBarBg`, and the sidebar sits on its own
  lighter `navBg` instead of sharing the frame tone.
- **Bar / now-playing architecture** — see below.
- **Now Playing extras** — up-next peek, in-place rating, FLAC/44.1 kHz-style
  fidelity badge, and Tier-1 party mode (fullscreen + hold-to-unlock, optional
  4-digit PIN, `WakeGuard` to keep the display awake).
- **macOS enablement** — the `macos/` runner, SPM-only deps, darwin server-path
  fix, app data moved out of `~/Documents` (TCC), and the visualizer's
  real-audio path via the `viz_decoder` sidecar + backdrop render mode.
- **The theme round → Onyx** — three tricolor candidates came out of the
  `shell-frame/` design-project round (Slate = v3's webapp blue-grays,
  Graphite = v2's neutral grays + amber lines, Onyx = the hybrid), A/B'd live.
  **Onyx won and is the desktop default** (resolved at read time via
  `SettingsManager.effectiveAppTheme`); Graphite is kept as the alternate;
  Slate was purged after the round. Onyx/Graphite are desktop-only entries in
  the theme picker (`AppTheme.isDesktopOnly`) — phones keep Velvet/Dark/Light.
  Final frame: four tones —
  title bar #0F0F0F (`titleBarBg`) · nav #262A33 (`navBg`) · content #1E2228 ·
  Now Playing bar #1A1A1A — with exactly ONE accent line, amber under the
  title bar (`titleBarLine`); the nav | content divider stays quiet #444C56
  (`border2`) and bar | content is a bare tone shift (its old hairline was
  removed shell-wide). Cards #2D333B ride above the nav tone. Amber accent
  unchanged.

## The bar / queue / Now Playing architecture (current)

The seek line started as a thin strip inside the bar (#4); it grew into the
whole layout below.

- **Now Playing bar** (120px): top pad · elapsed/duration row · waveform band ·
  the controls row. The waveform strip floats on the shell's root `Stack`
  straddling the content/bar boundary (`Positioned` in `_DesktopShellState`),
  spanning sidebar → the now-playing card. Thumb on hover only.
- **Now-playing card** owns the bar's full-height right corner and stays put
  whether the queue is open or closed: 88px art on the LEFT, then title /
  artist / album·year / a badges row (BPM · key · LYRICS, from the queue's
  metadata extras). Two glyphs sit bottom-right — expand (opens the
  full-screen Now Playing; hover-brightens, never state-highlighted) and the
  folded queue glyph at the corner (amber while the queue is open). The whole
  card toggles the queue; the art is plain (an art-tap opening Now Playing
  wasn't discoverable).
- **Queue column** reads a "Queue" header (light-red clear · a save/download/
  share ⋮ menu; closing lives on the bar's queue glyph — the header's ✕ read
  as "clear") → the track list, durations on each row's bottom line. It shares
  the content field with the browser (no divider), web-app style.
- **Full-screen Now Playing** (#7) covers the whole shell: blurred album art or
  the live shader visualizer as backdrop (corner toggle, no reflow between
  states), the shared waveform + transport, a synced-lyrics pane (#8), up next,
  rating + fidelity badge, and the party-mode lock.

## Ground rules learned

- One visual change per verdict; keep each independently revertable.
- Judge feel/perf on RELEASE builds only (debug JIT lies about jank).
- The hover-play button on album cards needs a side-effect-free album-songs
  fetch (the current API call drives browse navigation) — follow-up for #3
  or whenever cards grow inline actions. The PATTERN now exists: #10 split
  search into `searchServerRaw` (structured results, no browse side effects)
  with the classic flat path layered on top — do the same for album songs.
- Result/row taps dispatch through `util/browse_actions.dart` (extracted from
  the browser in #10) — any new surface that shows DisplayItems (dashboard
  shelves, context menus) should reuse it, not re-implement per-type taps.
