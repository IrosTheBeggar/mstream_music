# Desktop Port Plan (Windows / Linux / macOS)

Status reference for bringing mStream Music to desktop via Flutter. Captures what
shipped on `feat/windows-desktop`, the feasibility findings for each remaining
feature, effort estimates, and the concrete technical path + gotchas for each.

**Branch:** `feat/windows-desktop` (off the worktree branch)
**Toolchain verified:** Flutter 3.44.0 stable, Visual Studio 2022 (C++ desktop
workload), Windows 10. `flutter build windows` works end-to-end.

Legend: ✅ done · 🟢 easy · 🟡 moderate · 🔴 hard · ⛔ blocked-by-environment

---

## 1. DONE — Windows desktop build + desktop shell ✅

A Windows build that compiles, launches, and plays, with a traditional desktop
player layout. Verified: `flutter analyze` clean, `flutter build windows`
(debug + release) exit 0, app boots into `DesktopShell` (default 1280×720 window
clears the breakpoint) with **no runtime exceptions** in the log; `libmpv`
registered and a media_kit-backed player constructed.

### Changes made
- **Scaffold:** `flutter create --platforms=windows --org com.example .`
  (org matches existing `com.example.mstream_music`; registers platform in
  `.metadata`, creates `windows/`).
- **`pubspec.yaml`:** added `just_audio_media_kit` + `media_kit_libs_audio`
  (resolved just_audio_media_kit 2.1.0 / media_kit 1.2.6 against just_audio
  0.10.3 cleanly). just_audio has no native Windows backend → route through
  libmpv on Windows/Linux only.
- **`lib/main.dart`:**
  - `JustAudioMediaKit.ensureInitialized()` gated to `Platform.isWindows ||
    Platform.isLinux`, before `MediaManager().start()` (must run before any
    `AudioPlayer` is built). No-op on mobile/macOS (those keep just_audio's
    native backend).
  - Portrait lock (`SystemChrome.setPreferredOrientations`) gated OFF on desktop.
  - Root switch in `MStreamApp.build`: returns `DesktopShell` when
    `(Win||Linux||macOS) && MediaQuery width >= 900`, else the unchanged phone
    shell. All `initState` lifecycle is shared — only the view tree differs.
- **`lib/singletons/media.dart`:** `AudioService.init` gated to
  `Platform.isAndroid || isIOS || isMacOS`; otherwise construct
  `AudioPlayerHandler()` directly. `audio_service` has no Windows/Linux platform
  impl. In-app playback is identical (the UI reads the handler's
  playbackState/mediaItem/queue streams either way) — only OS media-session
  integration is lost on Win/Linux.
- **`lib/media/audio_stuff.dart`:** added `AudioPlayerHandler.setVolume(double)`
  passthrough to `_backend.setVolume`, for the desktop volume slider.
- **`lib/widgets/desktop_shell.dart`** (NEW): the desktop layout — see §3.

### Why it "just built"
The Android-only plugins (`flutter_chrome_cast`, `media_cast_dlna`,
`mobile_scanner`, `audio_service`) declare **no Windows native code**, so the
Windows CMake build SKIPS them rather than failing. They were already runtime
gated (`Platform.isAndroid` / `IrohTunnel.isSupported` / cast discoverers
registered Android-only). `permission_handler` has a real Windows impl. Startup
method-channel calls (`mstream/insecure_tls`, `mstream/storage`) already swallow
`MissingPluginException`.

---

## 2. Binary size (Windows x64)

| Build | Bundle | Notes |
|---|---|---|
| Debug | 158 MB | JIT engine + 6.5 MB `.pdb` — not representative |
| **Release** | **51 MB** | shippable folder; ~20–25 MB zipped |

Release breakdown: `flutter_windows.dll` 20.3 MB (engine) · `libmpv-2.dll`
14.8 MB (media_kit) · `data/app.so` 9.9 MB (AOT Dart) · MaterialIcons font
1.6 MB · `icudtl.dat` 0.8 MB · plugin DLLs (small). The `.exe` itself is ~0.5 MB
(Flutter ships a folder, not one file).

Size levers (optional):
- **libmpv (15 MB)** is the biggest discretionary chunk — see §7 audio tradeoff.
- **MaterialIcons shipped whole (1.6 MB)** — icon tree-shaking didn't trigger
  (likely a dynamic `IconData` somewhere); ~1.3 MB recoverable.

Visualizer impact: Path A adds ~nothing; Path B (native projectM) adds a few MB.

---

## 3. Architecture — responsive shell pattern

Flutter has no CSS/media-query restyling: "responsive" = branch the widget tree
on size. For a *radically* different desktop design, branch ONCE near the root
into a fully independent shell, and keep all state out of the widgets (the app
already does — singletons + streams), so both shells are views over the same
state with no logic duplicated.

`lib/widgets/desktop_shell.dart` structure:
- **Left sidebar (248px):** logo · server picker (mirrors the phone app bar's
  `ServerManager` calls) · `Library` · `Share` · `TOOLS` group (Manage Servers,
  Auto DJ, Transcode, Settings, Diagnostics, About).
- **Content pane:** a nested `Navigator` so tool screens push WITHIN it (sidebar
  + player stay visible). Initial route = browse view: `BrowserToolbar` +
  `IndexedStack[Browser, AlbumDetailView]` driven by
  `BrowserManager().albumDetailStream` (same model as the phone shell).
- **Right queue panel (toggleable):** reuses `QueueList`.
- **Bottom Now Playing bar (full width, 88px):** art · title/artist ·
  shuffle/prev/play/next/repeat · seek slider w/ times · volume slider · queue
  toggle. Reads `MediaManager().audioHandler` (`playbackState`, `mediaItem`,
  `positionStream`) and calls the same handler methods the phone player uses.

Known rough edges (first functional pass):
- Not pixel-tuned; spacing is reasonable defaults.
- Tool screens render their *mobile* page (own Scaffold + AppBar + back) inside
  the content pane — functional, slightly un-native. Making them inline desktop
  panes is follow-up.
- Crossing the 900px breakpoint rebuilds the shell (browser scroll may reset;
  state survives via the singletons).
- Desktop-only labels (`Library`, `Queue`, `Add server`) are hardcoded English —
  not yet in the ARB files. Localize later.
- Cast button omitted on desktop (no Windows discoverers — see §6).

---

## 4. Feature roadmap (effort-ranked)

| Feature | Effort | One-line |
|---|---|---|
| iroh tunnel (§5) | ✅ done (Win) | DLL builds + bundles; native FFI verified loading on Windows |
| Shader visualizer — Path A (§6) | 🟢 low | Pure-Flutter `ui.FragmentShader`, no native code |
| Linux build (§8) | 🟡 low–mod | Code already branches Linux; work is libmpv packaging + build env |
| projectM visualizer — Path B (§6) | 🟡 moderate | Reuse GLES engine via ANGLE, needs texture bridge + libprojectM build |
| Chromecast / DLNA (§7) | 🔴 hard | Backend reimplementation against pure-Dart `dart_cast` |
| OS media session (§9) | 🟡 per-OS | smtc_windows / mpris_service / audio_service(macOS) |

Suggested order: **iroh → shader visualizer → Linux → (decide on) projectM /
Chromecast**. iroh is the quickest high-impact win (remote server access reusing
proven native code).

---

## 5. iroh remote tunnel — ✅ DONE on Windows (Linux/macOS pending)

**Landed (Windows):**
- `rust/iroh_tunnel` builds for `x86_64-pc-windows-msvc` unchanged: `cargo build
  --release` → `iroh_tunnel.dll` (9.6 MB, all 9 `mstream_iroh_*` C ABI symbols
  exported).
- DLL committed at `windows/iroh/iroh_tunnel.dll` (mirrors the jniLibs
  prebuilt-.so convention) and bundled next to the exe by an `OPTIONAL` install
  rule in `windows/CMakeLists.txt`.
- `lib/native/iroh_tunnel.dart`: `_irohLibName()` picks the per-platform filename;
  `_probeSupport()` now allows Android + Win/Linux/macOS; the start() error
  message is platform-neutral.
- Startup diagnostic in `main.dart` logs `[iroh] native tunnel supported` + idle
  `status` (the latter forces the FFI bindings to resolve).
- **Verified on Windows:** `isSupported` → true and a real native call
  (`mstream_iroh_status()`) round-trips, returning `down`, with no error.

**Pairing UX (already works on desktop):** the add-server iroh tab already has a
`_pasteIrohCode()` clipboard path and `_testIrohConnection()` — both now function
on desktop (the latter was gated on `IrohTunnel.isSupported`, now true). Fixed
`_scanQr()` to gate on the platform (Android/iOS camera) instead of
`isSupported`, so on desktop it falls back to "scan is mobile-only" rather than
opening the no-op `mobile_scanner` page. So: paste code → Test → Save is a
complete desktop pairing flow.

**Still to do:**
- **Linux/macOS:** `cargo build` for those triples + bundle via `linux/`/`macos/`
  CMake. The Dart loader + probe already handle them.
- **Full connect test** needs a paired iroh server (the pairing code) — the
  connect path itself is the platform-neutral Rust already proven on Android.
- Replace the startup-diagnostic `status` read if its eager FFI-binding init on
  Android startup is unwanted (it's microseconds, but it's a behavior delta).

---

### Reference: why this was easy

The native code is **already cross-platform Rust that already builds on desktop.**

Evidence (`rust/iroh_tunnel/`):
- `Cargo.toml`: Android-only deps (`jni`, `ndk-context`) are already behind
  `[target.'cfg(target_os = "android")'.dependencies]`; core deps (`iroh`,
  `tokio`, `iroh-tickets`) are platform-neutral; `crate-type = ["cdylib",
  "rlib"]`; there's a `[[bin]] iroh-tunnel-client` dev binary that already runs
  on the desktop host.
- `src/lib.rs`: `mod android_init` is `#[cfg(target_os = "android")]`-gated (it's
  the JNI/ndk-context registration iroh needs *only* on Android for network
  monitoring).
- `src/c_api.rs`: every `#[no_mangle] extern "C"` export the Dart side looks up
  (`mstream_iroh_start/stop/is_active/status/network_changed/path_kind/
  local_token/last_error/string_free`) is **unconditional**. Only `log_android`
  is cfg-split, and it has a `#[cfg(not(target_os = "android"))]` no-op fallback.

### Work
1. **Build:** `cargo build --release` for the desktop triple →
   `iroh_tunnel.dll` (Win) / `libiroh_tunnel.so` (Linux) / `.dylib` (macOS).
2. **Bundle:** copy the lib next to the exe (CMake step in `windows/`/`linux/`,
   or wrap as a small FFI plugin for proper bundling).
3. **Dart (~10 lines, `lib/native/iroh_tunnel.dart`):** make `_Bindings.open()`
   and `_probeSupport()` use the platform-appropriate library name instead of
   hardcoded `'libiroh_tunnel.so'`, and drop the `if (!Platform.isAndroid)
   return false;` early-return. `IrohTunnel.isSupported` already probe-loads and
   degrades gracefully — it was built to flip on exactly this way.

### Notes
- iroh runs *better* on desktop: native OS interface monitoring → self-detects
  network changes (the manual `networkChanged()` nudge is an Android-only crutch
  for the missing ndk-context monitor). Desktop NATs are friendlier to
  hole-punching.
- Loopback model unchanged: point base URL at `http://127.0.0.1:<port>`; random
  loopback token auth (`getrandom`) works as-is.
- **Pairing UX:** paste the base64url pairing code (no camera/`mobile_scanner` on
  desktop).
- Adds a Rust toolchain step to desktop CI (`rustup target add` + `cargo build`).
  macOS `.dylib` needs signing/notarization for distribution.
- Test: `IrohTunnel.isSupported` flips true + symbols resolve; a full connect
  needs a paired server.

---

## 6. Visualizer

Two engines (`android/app/src/main/cpp/`):
- **projectM (Milkdrop)** — needs `libprojectM-4` native lib (FFI in
  `lib/native/projectm_bindings.dart`, gated to `Platform.isAndroid`).
- **ShaderEngine** (`shader_engine.h`) — Shadertoy-convention GLSL ES fragment
  shaders, multi-pass with ping-pong FBOs, audio published as a 512×2 FFT
  texture. Presets are GLSL **strings in Dart** (`lib/native/
  visualizer_presets.dart`, `user_shaders.dart`), not platform code.

**Audio input is already pure Dart:** `lib/singletons/visualizer_audio.dart`'s
default "synthesized" PCM source has no platform dependency (the Android
`Visualizer` effect is the only platform-specific path). So feeding audio is NOT
a blocker on desktop.

### Path A — pure-Flutter shader visualizer — ✅ landed (5 of 9 presets)
Windows-verified, builds clean. A "Visualizer" sidebar entry opens a Ticker-driven
`CustomPaint`; `lib/visualizer/spectrum_source.dart` synthesizes PCM → in-Dart
radix-2 FFT → a **512×2 audio texture** (row 0 = spectrum, row 1 = waveform)
uploaded as the `iChannel0` sampler, so the ported shader bodies run unchanged.
Tap or ‹ › cycles presets.

**Ported (`shaders/visualizer/*.frag`) — 6 single-pass presets ship:** 01 Spectrum
Bars, 02 Audio Tunnel, 03 Plasma Pulse, 06 4D Beats, 07 Neonwave Sunrise, 08
Neonwave Sunset. Mechanical port (preamble + `mainImage`→`main()` with a y-flip +
`iParams` baked to preset defaults). **06** additionally needed a hand rewrite: its
comma-operator body AND its non-standard for-header (`for(vec3 r=…; ++i<77.;
z+=…)` — declares one var, tests another, increments a third) are both rejected by
SkSL ("missing init declaration"); rewritten into a plain counting loop with
statement body + `mat2`-from-scalars.

**Multi-pass harness — built; 04 ported (7th preset).** `lib/visualizer/
viz_renderer.dart` adds a `VizRenderer` abstraction: `SinglePassRenderer` (the
existing path) + `MultiPassRenderer`, which runs passes in order each frame —
buffer passes render to offscreen images via `Picture.toImageSync`, the `image`
pass draws to screen; a pass listing its own name reads last frame's image
(ping-pong feedback). **04 Cyber Fuji** ships (buffera = 1×1 self-feedback band
buffer + image). Builds clean on Windows; the offscreen ping-pong render path
itself needs a visual check (only runs when that preset is selected).

**05 hex-marching — ported (8th preset).** 4 passes on the harness: buffera
(full compute) → bufferb (full-size ping-pong) → bufferc (1×1 music state) →
image. Its loops use runtime bounds but are well-formed with constant maxima, so
SkSL accepts them. Builds clean; visual/perf (full-res `toImageSync` each frame)
needs a check.

**09 mountainbytes — NOT portable to Flutter's SkSL backend.** Two hard SkSL
runtime-effect limitations, both architectural to the shader:
1. **Samplers as function parameters are forbidden.** 09's `rayMarch`/`hf`/`fbm`
   helpers take `sampler2D` args and pass buffer textures around
   (`unexpected SAMPLER, expecting RIGHT_PAREN`). SkSL requires samplers used
   directly, not passed — so every helper would have to be inlined/duplicated per
   buffer.
2. **Unbounded loops.** SkSL ES2 *unrolls* loops, so bounds must be constant;
   09's raymarch/fbm loop on runtime counts. Capping with a constant max + `break`
   clears the error but forces a large unroll.
   (1) is the dealbreaker — it would mean rewriting the 766-line shader's core.
Would only work on **Impeller** (real loops, sampler params) once Windows Impeller
is stable, or via a ground-up rewrite. Omitted from the preset list.

**Net: 8 of 9 shaders ported** (01–08; 09 is SkSL-infeasible).

**Key constraint:** Flutter `FragmentProgram` needs *precompiled* `.frag` assets
(no runtime GLSL string compile) AND the Windows/Skia backend is stricter than
desktop GL — exotic GLSL (comma-operator bodies, etc.) is rejected. Next:
real-audio capture to replace the synth source; optional fullscreen; the 06
rewrite / multi-pass harness if wanted.

Original sketch of the approach:
Reimplement the Shadertoy rendering with Flutter's built-in `ui.FragmentShader`
(runtime GLSL, all platforms incl. web). Audio FFT → a sampler image;
`iTime`/`iResolution`/`iParams` → float uniforms; drive with a `Ticker` into a
`CustomPaint`.
- No native libs, no ANGLE, no C++ texture-registry work. Reuses the GLSL presets
  already in Dart. Adds ~nothing to the binary.
- Single-pass is easy; multi-pass feedback buffers need `PictureRecorder`→`Image`
  ping-ponging (more work).
- Gives the Shadertoy-style visualizers — **not** the Milkdrop preset library.
- **Realistic near-term path** to *a* visualizer on desktop.

### Path B — native projectM (Milkdrop) — 🟡 Phase 1 done (engine loads on Windows)

**Done:** built **libprojectM v4.1.6 → `projectM-4.dll`** for Windows (MSVC, from
`C:\Users\paul\build\projectm`; needs GLEW — fetched the official 2.1.0 prebuilt).
Committed `projectM-4.dll` + `glew32.dll` under `windows/projectm/`, bundled next
to the exe via an OPTIONAL CMake install (mirrors iroh/jniLibs). Un-gated
`ProjectMBindings._open()` for Windows. **Verified:** the app logs
`[projectm] libprojectM loaded · v4.1.6` — DLL loads, glew32 resolves, FFI binds,
version round-trips. (Built desktop-GL/GLEW, not GLES/ANGLE — simplest path for an
offscreen WGL context + CPU readback.)

**Still to do (Phase 2 — the big native piece):** offscreen WGL context +
`glewInit` + FBO; per-frame `projectm_pcm_add_float` (synth PCM) +
`projectm_opengl_render_frame`; present to Flutter via `glReadPixels` → Dart
`ui.Image` (before any GPU texture sharing); load `.milk` presets
(`assets/presets/`, 120) via `projectm_load_preset_file`; desktop projectM screen
+ switcher. A native FFI shim (like iroh) — unverifiable without eyes on it.

### Path B reference — via ANGLE
The C++ engines are already `EGL` + `GLES3`; Flutter's Windows embedder ships
**ANGLE** (EGL/GLES over D3D11), so the engine code largely compiles against it.
- Replace the Android `SurfaceTexture`/JNI bits with an offscreen ANGLE EGL
  context + FBO, presented through a Windows Flutter texture
  (`flutter::TextureRegistrar` — GPU surface via D3D11 share-handle for
  zero-copy, or simpler pixel-buffer `glReadPixels` readback).
- Build **libprojectM-4 for Windows** (cross-platform CMake; vcpkg or source).
- Re-expose the `mstream/visualizer` MethodChannel from a Windows plugin; un-gate
  the `Platform.isAndroid` checks in `lib/screens/visualizer_screen.dart` and
  `lib/native/projectm_bindings.dart`.
- Full parity incl. `.milk` presets; reuses engine logic. Adds a few MB.
- **Linux is easier than Windows here** — native EGL/OpenGL, no ANGLE
  indirection.

---

## 7. Chromecast / DLNA — 🔴 HARDEST

**Blocker:** `flutter_chrome_cast` wraps Google's native Cast SDK, which only
ships for Android/iOS/Chromium — there's no desktop Cast sender SDK. `media_cast_
dlna` is likewise Android/iOS-only. Both are cleanly skipped on the desktop build.

**The architecture was designed for this swap.** `lib/media/device_discoverer.dart`
doc: keeping discovery behind the interface means the package choice "(e.g.
dart_cast vs flutter_chrome_cast) can be made — and changed — without touching
anything above this seam."

### Path: pure-Dart CASTV2 sender
Chromecast = (1) mDNS discovery (`_googlecast._tcp`), (2) TLS+protobuf "CASTV2"
control channel (launch Default Media Receiver, `LOAD`/`PLAY`/`PAUSE`/`SEEK`/
`STOP`), (3) device fetches media by URL over HTTP. The [`dart_cast`](https://pub.dev/packages/dart_cast)
package implements this in pure Dart (ported from `node-castv2`), explicitly
supports Windows/Linux/macOS, and also does DLNA + an HTTP proxy.

| Piece | Status |
|---|---|
| `CastManager`, `CastTarget`, picker UI, `PlaybackBackend` seam | reuse unchanged |
| `LocalMediaServer` (serves files to renderers) | reuse — already pure Dart |
| `EmulatedPlaylistBackend` (playlist/index/transport arithmetic) | reuse |
| `DesktopChromecastDiscoverer` | new, small (wrap dart_cast mDNS) |
| ~6 device ops in `ChromecastPlaybackBackend` (currently `GoogleCastRemoteMediaClient`/`SessionManager`) | reimplement against dart_cast |
| Registration | un-gate `if (Platform.isAndroid)` in `media.dart` |

### Gotchas
- **Self-signed mStream servers:** the Chromecast fetches the stream itself and
  won't trust a self-signed cert (already bites Android casting). Mitigation: the
  desktop app already runs `LocalMediaServer` — proxy the auth'd/self-signed
  stream and re-serve to the device over plain LAN HTTP. dart_cast's
  header-injection proxy helps. (Desktop actually has a *cleaner* cast story.)
- Codec constraints (Default Media Receiver: MP3/AAC/FLAC/Opus/Vorbis/WAV) —
  existing transcode layer handles these.
- The **visualizer-to-Chromecast** sub-feature (`_visualizer` mode in
  `ChromecastPlaybackBackend`, casts the on-device visualizer as HLS video)
  relies on the Android native MediaCodec transcoder → leave out; audio casting
  only to start.
- dart_cast is a community reimplementation of an unofficial protocol — evaluate
  maturity/activity before committing (the stable receiver protocol rarely
  changes, so risk is low but nonzero).
- **Bonus:** the same swap restores **DLNA** on desktop (dart_cast does DLNA too;
  it's just SSDP + SOAP over HTTP).

Estimate: discoverer ~1 day; backend rewrite + testing against a real device is
the bulk (a few days); audio-only first.

---

## 8. Linux build — 🟡 / ⛔ (needs a Linux env)

Officially supported (Flutter 3.0+, GTK 3 embedder, Canonical co-maintains).
Skia today; Impeller Vulkan in development for 2026.

**The code is already Linux-ready** — everything written for Windows branches on
Linux too: `JustAudioMediaKit.ensureInitialized()` fires on Linux; the
`AudioService.init` guard routes Linux to direct-construct; the `DesktopShell`
switch includes Linux; the portrait guard excludes it. Android-only plugins are
skipped, same as Windows. `flutter build linux` should work with little-to-no
extra Dart.

### Linux-specific gotchas
1. **media_kit links the SYSTEM libmpv**, not a bundled DLL (`sudo apt install
   libmpv-dev mpv` to build). Packaging (Snap/Flatpak/.deb) must declare/bundle
   mpv, or playback fails at runtime ("Cannot find libmpv"). This is the #1
   packaging concern.
2. Toolchain: `clang cmake ninja-build pkg-config libgtk-3-dev`.
3. Packaging fragmentation (deb/rpm/AppImage/Snap/Flatpak/pacman) — the real
   "Linux tax"; Snap/Flatpak are most turnkey.
4. Media keys need **MPRIS** (`mpris_service`) — the Linux analog of Windows SMTC.
5. `permission_handler` has no real Linux impl — fine (desktop needs no runtime
   perms).

### Practical
Flutter **doesn't cross-compile** desktop. From Windows you need a Linux env:
WSL2 (builds fine, GUI via WSLg), a VM, a real box, or **CI** (GitHub Actions
`ubuntu-latest` is the cleanest for releases). ⛔ this is the new piece vs Windows.

**Strategic:** mStream's self-hoster audience skews heavily Linux — higher ROI
than for a typical consumer app. A native visualizer (Path B) is also *easier* on
Linux (native EGL/GL).

---

## 9. Cross-cutting

- **OS media session** (media keys / now-playing): none on desktop yet. macOS =
  `audio_service` works; Windows = add `smtc_windows`; Linux = `mpris_service`.
  The handler architecture is ready (the UI reads its streams regardless).
- **Audio backend tradeoff:** media_kit/libmpv (≈15 MB, broad format support, one
  backend for Win+Linux) vs `just_audio_windows` (wraps WinRT MediaPlayer,
  smaller, Windows-only). Currently on media_kit.
- **CI / packaging:** a multi-platform release pipeline would build Windows
  (native or `windows-latest`), Linux (`ubuntu-latest` + GTK/mpv deps), and add a
  Rust step once iroh lands. Pick distribution formats per OS (zip/MSIX on
  Windows; AppImage/Snap/Flatpak on Linux).

---

## 10. Open follow-ups / polish
- Localize the desktop-only strings (move `Library`/`Queue`/`Add server` to ARB).
- Make tool screens inline desktop panes instead of pushed mobile pages.
- Tighten Now Playing bar proportions / overall visual polish.
- Recover ~1.3 MB via icon tree-shaking (find the dynamic `IconData`).
- Decide on OS media-session integration per platform.

_All changes for §1 are uncommitted on `feat/windows-desktop` as of this writing._
