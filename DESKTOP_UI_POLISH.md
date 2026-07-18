# Desktop UI polish — working list

Design ideas gathered from the state of the art in desktop music players
(Harmonoid, Plexamp, Feishin, Spotube, Cider, Spotify) and mapped onto this
app. Worked ONE item at a time, with a look at the running release build
between each — batched visual changes can't be judged piecewise.

Companion doc: `DESKTOP_PORT_PLAN.md` (platform/feature feasibility).

## Status

| # | Item | Status |
|---|------|--------|
| 1 | Custom title bar (hide native chrome, app-drawn caption) | **Skipped** — keeping native chrome |
| 2 | Hover affordances (theme hoverColor + album-card lift) | **Done** |
| 3 | Right-click context menus mirroring the ⋮ menus | Pending — next up |
| 4 | Slim seek line | **Done** — evolved, see below |
| 5 | Album-card polish (240px tiles, resting depth, type hierarchy) | **Done** |
| 6 | Art-adaptive accent color (palette from playing album) | Pending |
| 7 | Full-screen Now Playing view — projectM/Milkdrop as the live backdrop | Pending — flagship differentiator |
| 8 | Synced lyrics pane (lyrics shipped in v0.30, surface on desktop) | Pending |
| 9 | Home dashboard landing (recently played / added / playlists shelves) | Pending |
| 10 | Ctrl+K global search / command palette | Pending |
| 11 | Windows SMTC (media overlay w/ art + transport, `smtc_windows`) | Pending |
| 12 | Mini player (small always-on-top window) | Pending — bigger lift |
| 13 | Queue redesign (now/up-next grouping) | Partial — card-on-top landed with #4 |
| 14 | Accent/theme customization | Pending — `VelvetPalette.withAccent` already exists |

## How #4 ended up (the current bar/queue architecture)

The first cut (line inside the bar, span limited to the transport region)
read as two stacked lines against the bar's top border and ate bar height.
Final design, per Paul's sketch:

- Everything right of the sidebar is a Column: content row (+ queue column
  when open) ABOVE a full-width Now Playing bar — so the bar always runs
  sidebar → screen edge, queue open or closed.
- The scrub line IS the content/bar boundary: no bar top-border, no in-bar
  strip; a 14px hit zone floats on the shell's Stack straddling the edge
  (`Positioned` in `_DesktopShellState.build`). Thumb appears on hover only.
- Queue column reads now-playing card → list; its actions (clear · save/
  download/share · close) dock in the bar's fixed right region — every
  control lives along the bottom. The transport keeps a constant width in
  both queue states (the right region is tab-or-queue-actions, same width).

## Ground rules learned

- One visual change per verdict; keep each independently revertable.
- Judge feel/perf on RELEASE builds only (debug JIT lies about jank).
- The hover-play button on album cards needs a side-effect-free album-songs
  fetch (the current API call drives browse navigation) — follow-up for #3
  or whenever cards grow inline actions.
