# Back to a pure desktop player — server-management removal plan

The server repo's `rust-launcher` (shipped as `mstream-launcher`) now owns
everything this app's embedded-server stack did, and does it better: it spawns
`mstream-server --supervised` holding the supervision pipe (the PR #800
contract — a killed launcher can never leak an orphan), and carries the tray
icon, autostart/login item, single-instance guard, health probing, boot
watchdog, update takeover, and rollback. This app returns to being what the
mobile builds are: a client. A user who wants to SERVE from their desktop runs
the launcher; this player connects to it like any other server.

Status quo that makes this urgent rather than optional: the embedded-server
path is already broken on this branch (stale bundled binary predating the
current server; the `__local__` entry resolves to a port-0 URL), and its
`launch_at_startup` dependency is what pins `share_plus`/`package_info_plus`
two majors behind master (win32-5 co-resolution).

## Inventory — what goes (~2,500 lines + 2 deps)

| # | Item | Where |
|---|------|-------|
| 1 | Server binary manager: download/verify/update, spawn (`--supervised` probe), health checks, pid resolution (`lsof`), orphan adopt/recycle, stop | `lib/server/server_controller.dart` (691 lines) + `maybeStartFor`/status wiring in `main.dart` (~156-160, 400-440, 519) |
| 2 | Tray icon + close-to-tray + launch-at-startup | `lib/desktop/desktop_integration.dart` (153), `assets/tray_icon.ico`, the Settings launch-at-login tile, tray asset rule in `pubspec.yaml`. **Except** `usesCustomTitleBar` — that's window chrome, not server management: it moves to `lib/util/desktop_platform.dart` before the file dies |
| 3 | First-run client/server mode chooser + quick server setup UI | `lib/screens/desktop_onboarding.dart` (612) + the `_serversLoaded` onboarding-cover gate in `main.dart` |
| 4 | Server-boot wait states: startup-view retry on server boot, boot-phase gates | `main.dart` `_armEmbeddedStartupRetry` + `_startupRetryListener/_startupRetryTimeout` |
| 5 | The attached-server concept on the model + its tendrils | `Server.isAttachedServer` + `__local__` backfill (`lib/objects/server.dart`), adoption paths in `ServerManager`, attached rows in `manage_server.dart`, browser add-server special cases |
| 6 | Diagnostics/settings surfaces for the embedded server | `diagnostics_screen.dart` server-ctl sections, Settings > Desktop rows that configure serving |
| 7 | Dependencies: `tray_manager`, `launch_at_startup` | `pubspec.yaml` — and with them the win32-5 pins die: **lift `share_plus` → ^13, `package_info_plus` → ^10** and delete both cap comments |
| 8 | l10n keys for all removed UI, across the ten ARB files | `lib/l10n/app_*.arb` + gen-l10n |

Window-close behavior changes with #2: close = quit (standard player
behavior, same as the Electron player). `window_manager` STAYS — it drives
the custom title bar, min window size, and party-mode fullscreen.

## What stays untouched

Everything that is the player: the desktop shell (Onyx/Graphite themes, title
bar, hotkeys, ⌘K search, waveform bar, queue, Now Playing, visualizers),
client-side LAN discovery (mDNS Quick Connect), the iroh tunnel client, local
files, downloads.

## Replacement seams (the three product decisions)

1. **First run on desktop** → the standard client flow (master's
   Welcome/SetupFlow now exists and works on desktop). Sweetener that keeps
   the launcher+player pairing feeling integrated: a "mStream Server detected
   on this machine" row in add-server/onboarding (probe `localhost:3000`,
   plus the existing mDNS scan) that one-click-adds the launcher's server.
2. **Existing installs with a `__local__` attached entry**: one-time
   migration to a plain server entry pointing at its localhost URL — kept if
   the launcher serves there, ordinary delete flow if not. No flag, no
   special casing after.
3. **"Where did serving go?"**: the add-server empty state and the docs
   point at the launcher download (mstream.io) for people who used the app
   as their server.

## Sequencing — each step lands green on its own

1. **Decouple boot**: remove `ServerController` from `main.dart` (spawn
   trigger, status gates, startup retry); app boots straight to the shell;
   `__local__` migration runs here. The stale-binary breakage disappears.
2. **De-tray**: delete `desktop_integration.dart` + tray asset; close =
   quit; `usesCustomTitleBar` relocates to `util/desktop_platform.dart`;
   Settings loses the launch-at-login tile.
3. **Onboarding**: delete `desktop_onboarding.dart`; desktop first-run
   rides the standard flow; add the local-server-detect row.
4. **Model cleanup**: `isAttachedServer` + adoption/recycle paths +
   manage-server/browser/diagnostics tendrils.
5. **Deps**: drop `tray_manager`/`launch_at_startup`, lift the share_plus /
   package_info_plus caps, prune l10n keys, full analyze/test/build sweep on
   macOS (and a Windows build when handy).
6. **Docs + PR**: `DESKTOP_PORT_PLAN.md` (serving = launcher's job now),
   polish-doc note, PR #84 description refresh.

## Risks / notes

- The EPIPE/orphan-server saga (PRs #799/#800) stays solved — the contract
  just has one supervisor now, the launcher.
- Post-removal smoke needs BOTH cases: launcher running (player connects to
  localhost like any server) and nothing running (clean offline placeholder,
  no spinner-forever).
- Windows loses close-to-tray with #2. If tray-while-playing ever comes back
  it's a player feature (mStream#795 shape: minimize-to-tray, playback
  continues) — out of scope here, noted so the removal isn't mistaken for a
  verdict on it.
