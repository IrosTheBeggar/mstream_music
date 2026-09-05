# iroh_tunnel — mStream remote-access tunnel client (Phase 2B / M1)

Native client for mStream's iroh remote-access tunnel ([mStream PR #643](https://github.com/IrosTheBeggar/mStream/pull/643)). It dials the server by its iroh EndpointId, completes the shared-secret handshake, and exposes the server as a **plain local HTTP origin** (`http://127.0.0.1:<port>`) that the Flutter app uses as its base URL — so the rest of the app is unchanged. See `../../IROH_TRANSPORT_PLAN.md` for the full plan.

This is a faithful Rust port of the server's reference client `scripts/mstream-iroh-client.mjs`.

## Status (M1)

- ✅ Rust core (`connect_tunnel`) implementing the full frozen wire contract.
- ✅ **Interop proven on desktop** against a replica of the PR #643 server: JSON request, **HTTP Range/seek (206, byte-correct)**, and concurrent requests all tunnel correctly.
- ✅ C ABI + Dart FFI binding; cross-compiles for `arm64-v8a` + `x86_64` at Android API 26.
- ✅ **Self-healing in place (Phase 2, 2026-09):** the reconnect supervisor's backoff is cut short by an app kick or by the home relay coming back (`wait_backoff`); `mstream_iroh_force_reconnect` re-binds the loopback listener on the SAME port and closes the current connection so the supervisor re-dials at once (iOS kills the listener during a suspension while QUIC survives); bridges wait up to 10 s for a swapped-in connection; a native events ring (`mstream_iroh_drain_events`) and the home-relay state (`mstream_iroh_relay_online`) feed the app's diagnostics + watchdog. The harness's KICK phase covers it.
- ✅ **Keyed tunnels + federation guest mode (ABI v2, 2026-09):** the native table holds tunnels by an app-chosen key (`mstream_iroh_start(key, code, port)` and every per-tunnel call takes the key; `mstream_iroh_network_changed` fans out), so a Quick Connect server and a directly-reached federated peer can run side by side, each on its own loopback port with its own supervisor. A `mstrfedg1:{t,g}` **guest ticket** (mStream `docs/federation-guest-ticket.md`) dials the peer's federation endpoint (ALPN `mstream/federation/1`) and presents the guest token on the first bi-stream instead of a secret. `mstream_iroh_set_credential(key, code)` swaps a running tunnel's credential **in place** — the daily guest-token refresh must not rotate the loopback port — and a tunnel whose supervisor gave up on a rejected handshake re-dials at once with the new one. `mstream_iroh_abi_version` (2) lets the Dart side refuse a stale binary. The harness's GUEST phase covers the dial, the rejection, and the swap.
- ⏳ **Pending (device loop):** stage the `.so` into `jniLibs`, build the APK, and confirm on a physical device against a live server (see *On-device acceptance* below).

## Frozen wire contract (must match the server byte-for-byte)

- Pairing code = versioned envelope `mstr<V>:<base64url(JSON{ t: <EndpointTicket>, s: <connectSecret base64> })>` (spec: mStream `docs/iroh-pairing-code.md`). v1 current; a bare (un-prefixed) body is legacy implicit v1; a newer version is rejected with an "update the app" error. secret = 32 bytes.
- ALPN = `mstream/tunnel/2`.
- Bind an ephemeral endpoint, wait for our home relay (`online()`, bounded) **before** dialing.
- Handshake on the **first** bi-stream: write the 32 secret bytes, then expect ASCII `"OK"` (a `"NO"`/reset means the secret was wrong or rotated → re-pair).
- **Guest mode** (mStream federation, `docs/federation-guest-ticket.md` there): a `mstrfedg<V>:<base64url(JSON{ t: <EndpointTicket>, g: <guest JWT> })>` ticket dials ALPN `mstream/federation/1` and writes the token bytes (≤ 2 KB, the peer's `HANDSHAKE_LIMIT`) on the first bi-stream; `"OK"`/`"NO"` as above, where `"NO"` means the token expired or its key was revoked → refresh it from the parent (`set_credential`), no re-pair. A `mstrfed<V>:` federation ticket (admin-to-admin, carries a standing key) is refused by name.
- Then **one bi-stream per inbound local TCP connection**; raw byte pipe both ways (one bi-stream == one TCP connection → full HTTP semantics, incl. range/seek). Clean EOF → `finish`/`shutdown`; either side erroring → `reset`/`stop` the partner.

## Layout

| Path | Role |
|---|---|
| `src/lib.rs` | async core: pairing parse, connect, handshake, the byte-pump bridge. |
| `src/ffi.rs` | owned global Tokio runtime + the tunnel table keyed by the app's id: `tunnel_start(key, code, port)`, `tunnel_stop(key)`, `tunnel_set_credential(key, code)`, … (dart:ffi has no ambient runtime, so we `block_on`). |
| `src/c_api.rs` | `#[no_mangle]` C ABI (`mstream_iroh_*`) consumed by `dart:ffi`. |
| `src/bin/client.rs` | dev CLI; drives the same `ffi` path the app uses. |
| `interop/harness.mjs` | stands up the PR #643 server side and drives the compiled Rust client through real HTTP. |
| `build-android.sh` | cross-compiles + stages the `.so` into the app's `jniLibs`. |

Dart side: `../../lib/native/iroh_tunnel.dart` (FFI wrapper; `IrohTunnel.instance.start(code)` → port).

## Binding choice: C ABI + `dart:ffi` (not flutter_rust_bridge)

The surface is small (abi-version, start / stop / status / path-kind / network-changed / local-token / last-error, force-reconnect / drain-events / relay-online, set-credential, string-free — 14 symbols), so a hand-written C ABI consumed via `dart:ffi` is lighter than an frb codegen step in the build/CI — one `.so` plus a small Dart wrapper. frb remains an option if a richer or streaming surface is ever needed. The Dart side probes `mstream_iroh_abi_version` first and reports the tunnel as unsupported (with the reason in `IrohTunnel.unsupportedReason`) against a binary older than ABI v2, whose `start` takes different arguments — refusing beats misreading.

## Run the interop test (desktop, no device needed)

```sh
cd interop && npm install          # @number0/iroh@next (v1)
cd .. && cargo build               # builds the dev client binary
node interop/harness.mjs           # Rust client ⇆ JS server; asserts JSON + Range + concurrency + reconnect + in-place kick + guest mode (federation ALPN, rejected token, in-place credential swap)
```

## Build for Android

```sh
rustup target add aarch64-linux-android x86_64-linux-android
cargo install cargo-ndk
export ANDROID_NDK_HOME=.../Android/Sdk/ndk/28.2.13676358
./build-android.sh                 # stages libiroh_tunnel.so into ../../android/app/src/main/jniLibs/<abi>/
```

Real shipped `.so` (release, `opt-level=z` + thin-LTO + stripped, API 26). The
binary is **committed** to `jniLibs` (the CI release runner has no Rust/NDK), so
these checksums let a reviewer/user verify the shipped artifact — **rebuild via
`./build-android.sh` and update this table whenever `src/` changes** (CI fails a
release if the `.so` is missing, but cannot detect a stale one):

| ABI | size | sha256 |
|---|---|---|
| arm64-v8a | **9.58 MB** (10,044,728 bytes) | `952b36f1a9aec2720d1f6fa5feb1ece6e902ab5ae67a390840e970abc75d1bb4` |
| x86_64 | 11.13 MB (11,674,240 bytes) — emulators only | `c3326d8736eb51339d9ebc8defe5c3cf69cfb82c93b1c65e56babdbf088c23d3` |

With Play app-bundle ABI splits, an arm64 device downloads only its own slice (~9.5 MB). iroh **core only** — no blobs/docs/gossip/rpc (the full off-the-shelf FFI is 31 MB).

The release **sideload APK is universal** (both ABIs) on purpose — it runs on arm64
phones and x86_64 emulators from one artifact. For a smaller arm64-only sideload
build use `flutter build apk --flavor full --split-per-abi --target-platform android-arm64,android-x64`
(the Play AAB always splits per device).

## On-device acceptance (the remaining M1 step)

1. Run a real mStream with PR #643, set `iroh.enabled`, copy the pairing code from the admin **Remote Access** panel.
2. `./build-android.sh` to stage the `.so`, then `flutter build apk --flavor full` (or `play`).
3. From a throwaway call: `final port = await IrohTunnel.instance.start('<code>');` then GET `http://127.0.0.1:$port/api/` → expect 200.

(M2 wires this into the `Server` model + QR-scan add-server UI; M3 adds lifecycle/hardening.)
