# iroh tunnel crate — one client core for every mStream client

**Status:** planned 2026-09-18; **E1 done the same day** — <https://github.com/IrosTheBeggar/mstream-iroh-tunnel>, tag `v0.1.0` (the crate as it left this repo: ABI 2, iroh 1.1.0), MIT, name `mstream-iroh-tunnel`, lib name `iroh_tunnel` kept. · **Scope:** move `rust/iroh_tunnel` out of
this repo into its own repository, and consume it from here, from
`mstream-terminal-player`, and from any third-party client. · **Companions:**
the terminal player's "Per-server tunnels and guest tickets" plan (its T1
consumes the crate — PLAN.md in that repo) and Phase 8 of
`FEDERATION_PLAN.md` here (independent: it touches no Rust).

---

## 1. Why

- **Three consumers now.** This app ships the crate as committed binaries in
  three places — `android/app/src/main/jniLibs/{arm64-v8a,x86_64}/libiroh_tunnel.so`,
  the iOS and macOS `iroh_tunnel.xcframework`s vended by
  `packages/iroh_tunnel_native` over SwiftPM, and `windows/iroh/iroh_tunnel.dll` —
  each rebuilt by hand with `rust/iroh_tunnel/build-{android,ios,macos}.sh`
  (Windows: a plain `cargo build`). The terminal player carries a second,
  889-line Rust port (`src/quickconnect.rs`) with no guest mode, no in-place
  credential swap and no loopback token. Third parties are the audience the
  C ABI, the `iroh-tunnel-client` dev CLI and the README were written for,
  three directories deep in a Flutter app.
- **The wire is frozen by the server** (mStream PR #643, #943; the three
  `docs/*.md` specs). One implementation means one place a bump lands and one
  harness that proves it (`interop/harness.mjs`: JSON, Range, concurrency,
  the kick, the GUEST phase — dial, refusal, in-place swap — against
  `@number0/iroh` 1.1.0).
- **A cargo git dependency on this repo works but is a stopgap**: it clones
  141 MB of app history into every consumer's build cache.
- **The two ports have already diverged.** This crate is on iroh 1.1.0, the
  player pins 1.0.3; this crate has the loopback token and guest mode, the
  player has a single-flight redialer with a cooldown and a staged
  diagnostic (`quickconnect-probe`). Merging them settles which semantics
  win (§3).

## 2. Options

| Option | Verdict |
|---|---|
| **A. Its own repo, `IrosTheBeggar/mstream-iroh-tunnel`** | **Recommended.** Small, its own CI and release cadence, publishable to crates.io, the natural home for a C header and per-platform binaries. |
| B. A `rust/` crate inside the mStream server repo | Puts it beside the specs and the reference JS client, but the server's CI is Node-shaped, its releases are the server's, and every client would depend on the server repo to build. |
| C. Subtree or submodule vendored into each consumer | Two copies again, each drifting. No. |
| D. crates.io only | Needs a repo anyway; publishing is a step of A, not an alternative. |

## 3. The crate

- **Name.** Package `mstream-iroh-tunnel`; `[lib] name = "iroh_tunnel"` kept,
  so the artifact names (`libiroh_tunnel.so`, `iroh_tunnel.xcframework`,
  `iroh_tunnel.dll`) and the C symbols (`mstream_iroh_*`, ABI v2) do not
  change — zero edits to `lib/native/iroh_tunnel.dart`, `IrohNative.kt`, the
  `Package.swift`s or `windows/CMakeLists.txt` here.
- **Contents**, moved with history (`git subtree split -P rust/iroh_tunnel`):
  `src/{lib,ffi,c_api,android_init}.rs`, `src/bin/client.rs`, `interop/`
  (harness, pairing-server, `package.json`), `build-{android,ios,macos}.sh`,
  README, `Cargo.toml`, `Cargo.lock`, `.gitignore`. `rust/viz_decoder` stays
  — it is the visualizer's, not a client core.
- **License.** The crate declares MIT today; this app and the player are
  GPL-3.0. Keep the crate permissive (MIT, or MIT OR Apache-2.0) so third
  parties can link it — it is a separate work whose API is the C ABI.
  Confirm before E1.
- **Features.** `c-abi` (default on: `c_api` + `ffi` compiled and exported;
  the player turns it off so no `#[no_mangle]` symbols land in its binary);
  `os-trust` → `iroh/platform-verifier` (the player needs the OS trust store
  for the corporate-proxy case; this app decides by running the Netskope
  probe with it on). Android-only deps stay `cfg(target_os = "android")`.
- **API the player needs** (E3): a staged connect — the four stages public
  (bind, relay, dial, handshake) or `connect_tunnel_staged(code, port,
  on_stage)` — so `quickconnect-probe` can say which stage died; a typed
  error (`DialError::{Rejected, Unreachable, BadCode}`) instead of matching
  "rejected" in the text; `Tunnel::local_url()`; `mstream_iroh_version()` in
  the C ABI. Additive, so ABI stays 2 — the rule: adding a symbol never
  bumps, changing one does.
- **Semantics to settle when the player's `Redialer` goes** (E3, with a
  test): one dial in flight per tunnel with other callers waiting on the
  status watch (the supervisor's `wait_backoff` and the bridges' 10 s wait
  for a swapped-in connection are this), and a cooldown after a failed
  re-dial so callers fail fast on a dead link instead of each serving a full
  dial timeout (the player's `DIAL_COOLDOWN`, 4 s — check the supervisor has
  the equivalent, add it if not).

## 4. Versioning

- Rust API: semver tags `v0.x.y`; `v0.1.0` is today's code (ABI 2, iroh
  1.1.0). A CHANGELOG from the first tag.
- C ABI: `ABI_VERSION` (2), bumped only for a breaking change; this app's
  binding refuses `< 2` (`IrohTunnel.isSupported`).
- Pins: this app in `tool/iroh-tunnel.properties` (the tag and the Android zip's
  SHA-256, read by the Gradle download task) and in the iOS `Package.swift`
  (the remote binaryTarget's url + checksum), both written by the fetch
  script; the `[iroh]` startup diagnostic prints what actually loaded
  (`mstream_iroh_version`); the player in its `Cargo.toml`.

## 5. CI in the new repo

- Every push: `cargo test` (14 unit tests today) and clippy on
  ubuntu / macos / windows; `cargo build --release --lib` per host.
- The interop harness: Node 22, `npm ci` in `interop/`, `node harness.mjs`.
  It needs UDP and the relay, so it runs on push with `continue-on-error`
  until it has been green for a while, then becomes required.
- On tag: cross-builds — Android `arm64-v8a` + `x86_64` (cargo-ndk, API 26,
  NDK 28), iOS device + simulator and macOS arm64 xcframeworks (a macOS
  runner; the scripts as they are, `IPHONEOS_DEPLOYMENT_TARGET=15.0`,
  `MACOSX_DEPLOYMENT_TARGET=11.0`), Windows x64 DLL, Linux x64 `.so` (the
  desktop port's Linux leg). Assets: one zip per platform, `SHA256SUMS`, the
  generated C header (`cbindgen` over `c_api.rs` → `include/mstream_iroh.h`),
  the dev CLI per host. The xcframework zips' `swift package
  compute-checksum` values go in the release notes for anyone on a remote
  `binaryTarget`. The xcframeworks are unsigned, as today: Xcode signs at
  embed.

## 6. Consumers

**This app.** The committed-binary model stays — release CI has no Rust
toolchain by design, and the three verification steps in `release.yml` keep
working unchanged. `tool/fetch-iroh-tunnel.sh <version>` downloads the tagged
assets, checks `SHA256SUMS`, stages them exactly where the build scripts put
them today (the jniLibs dirs, the two xcframeworks under
`packages/iroh_tunnel_native/`, `windows/iroh/`) and writes
`tool/iroh-tunnel.version`. `rust/iroh_tunnel/` and the three `build-*.sh`
go; docs follow (`IROH_TRANSPORT_PLAN.md`'s header, `windows/iroh/README.md`,
`DESKTOP_PORT_PLAN.md` §5, the comments in `release.yml` and
`packages/iroh_tunnel_native/pubspec.yaml`). Later and optional: SwiftPM
`binaryTarget(url:checksum:)` for Apple and a Gradle download task for
Android, so binaries stop being committed — the history cost is already paid,
so do it when the next binary bump would add another 40 MB.

**Done 2026-09-19, ahead of the next bump.** The iOS `Package.swift` is a
remote `binaryTarget(url:checksum:)` on the release asset (Xcode downloads it
at package resolution and checks the published SwiftPM checksum); the Android
build has `downloadIrohTunnel` + `unpackIrohTunnel` tasks in
`android/app/build.gradle` (the zip cached under
`~/.gradle/caches/mstream-iroh-tunnel/`, checked against the SHA-256 in
`tool/iroh-tunnel.properties`, unpacked into `build/` and added to the jniLibs
source set). `tool/fetch-iroh-tunnel.sh <tag>` now verifies a release and
moves the two pins instead of staging files; the `Frameworks/` xcframework
and the two `libiroh_tunnel.so` are gone from git. The release workflow's
three verification steps are unchanged and now also prove the fetch. The
desktop branch's macOS and Windows binaries stay committed until it does the
same.

**The terminal player.** T1 of its plan: `mstream-iroh-tunnel = { version,
default-features = false, features = ["os-trust"] }` under its non-wasm
dependencies; its own port goes except the identity conventions and the
probe, which moves to the staged API in E3.

**Third parties.** The README's frozen-contract section, the header, the
release binaries, and `iroh-tunnel-client <code>` as the reference client
beside the server's `scripts/mstream-iroh-client.mjs`. The specs stay in the
mStream repo; its `docs/iroh-pairing-code.md` and
`docs/federation-guest-ticket.md` gain a "client library" link.

## 7. Steps

- **E1 ✅ 2026-09-18** — the repo from `git subtree split` (25 commits of
  history, master's `7d477df`; `build-macos.sh` ported from
  `feat/windows-desktop`, which master never carried); the package renamed;
  the MIT file; README for the three audiences; CI (tests, clippy with
  warnings as errors, a build on the three hosts; the harness advisory).
  The build scripts stage into `dist/<platform>/` or into
  `$IROH_TUNNEL_DEST` — so until E5 this repo can keep its committed
  binaries current with, e.g.,
  `IROH_TUNNEL_DEST=../mstream_music/android/app/src/main/jniLibs ./build-android.sh`
  from a checkout of the crate. Tagged `v0.1.0`. (S)
- **E2 ✅ 2026-09-18** — the player moved to `v0.1.0` (its T1: the registry
  of `iroh_tunnel::Tunnel`s in its api worker, its own dial and bridge code
  gone, the loopback token on every URL; iroh pinned at 1.1.0 there too).
  Two things it wants from E3 first: the staged connect for its probe, and
  a typed rejection instead of matching the error text.
- **E3 ✅ 2026-09-19** — the API round: the `c-abi` and `os-trust` features,
  typed `DialError`s (a refusal by connection close counts as one), `inspect`,
  the staged connect, `local_url()`, `mstream_iroh_version` (ABI stays 2, 15
  symbols), and an offline end-to-end test against a fake server endpoint.
  The cooldown check: the crate's supervisor is the one dial in flight and a
  request during a dead spell waits at most 10 s on the status watch before
  closing cleanly — the player's two properties, so no code was added. Tag
  `v0.2.0`. (M)
- **E4 ✅ 2026-09-19** — the tag workflow (`.github/workflows/release.yml`):
  the Android .so pair, the iOS and macOS xcframeworks, the Windows .dll, the
  Linux .so, the dev clients, the cbindgen header checked against the
  committed one, `SHA256SUMS`, the SwiftPM checksums; `workflow_dispatch`
  re-runs it for an existing tag. Exercised by `v0.2.0` and a dispatched
  `v0.1.0`, so the binaries this app committed have matching assets. (M)
- **E5 ✅ 2026-09-19** (this branch; binaries re-staged from the `v0.2.0`
  release by the script — 15 exports on every slice, one more than the
  committed ones, `mstream_iroh_version`; sizes within 1 % of the hand builds;
  the Android and iOS smoke suites have NOT run on them yet, which is the
  review's job before this merges) — this app: the fetch script and version file; delete
  `rust/iroh_tunnel` and the build scripts; the docs; re-stage every binary
  from the release and diff the exported symbols against the committed ones
  (same source, same toolchain — sizes may differ by build host); run the
  Android smoke suite and the iOS simulator round. Land after Phase 8a's rig
  run or on its own branch — Phase 8 touches no Rust, so this is ordering,
  not conflict. (S–M)
- **E6** — optional: `cargo publish` on tag; the SwiftPM remote binary target;
  the Gradle download task. (S each)

## 8. Risks and open questions

- The harness needs the relay and UDP from a GitHub runner — unproven, which
  is why it starts non-blocking.
- The semantics merge in E3 is one PR with one test; the player's listening
  smoke round (the "tunnel is flakey" case) is the acceptance.
- License (MIT for the crate) and name (`mstream-iroh-tunnel`) — confirm
  before E1; both are hard to change after a crates.io publish.
- The two worktrees under `.claude/worktrees/` carry copies of
  `rust/iroh_tunnel`; the split reads this branch's path, not those.
- Nothing here changes the wire, the ABI, or what this app's users see; a
  stale committed binary stays the one failure the verification steps
  cannot catch, exactly as today.
