# iroh_tunnel — mStream remote-access tunnel client (Phase 2B / M1)

Native client for mStream's iroh remote-access tunnel ([mStream PR #643](https://github.com/IrosTheBeggar/mStream/pull/643)). It dials the server by its iroh EndpointId, completes the shared-secret handshake, and exposes the server as a **plain local HTTP origin** (`http://127.0.0.1:<port>`) that the Flutter app uses as its base URL — so the rest of the app is unchanged. See `../../IROH_TRANSPORT_PLAN.md` for the full plan.

This is a faithful Rust port of the server's reference client `scripts/mstream-iroh-client.mjs`.

## Status (M1)

- ✅ Rust core (`connect_tunnel`) implementing the full frozen wire contract.
- ✅ **Interop proven on desktop** against a replica of the PR #643 server: JSON request, **HTTP Range/seek (206, byte-correct)**, and concurrent requests all tunnel correctly.
- ✅ C ABI + Dart FFI binding; cross-compiles for `arm64-v8a` + `x86_64` at Android API 26.
- ⏳ **Pending (device loop):** stage the `.so` into `jniLibs`, build the APK, and confirm on a physical device against a live server (see *On-device acceptance* below).

## Frozen wire contract (must match the server byte-for-byte)

- Pairing code = `base64url(JSON{ t: <EndpointTicket>, s: <connectSecret base64> })`, secret = 32 bytes.
- ALPN = `mstream/tunnel/2`.
- Bind an ephemeral endpoint, wait for our home relay (`online()`, bounded) **before** dialing.
- Handshake on the **first** bi-stream: write the 32 secret bytes, then expect ASCII `"OK"` (a `"NO"`/reset means the secret was wrong or rotated → re-pair).
- Then **one bi-stream per inbound local TCP connection**; raw byte pipe both ways (one bi-stream == one TCP connection → full HTTP semantics, incl. range/seek). Clean EOF → `finish`/`shutdown`; either side erroring → `reset`/`stop` the partner.

## Layout

| Path | Role |
|---|---|
| `src/lib.rs` | async core: pairing parse, connect, handshake, the byte-pump bridge. |
| `src/ffi.rs` | owned global Tokio runtime + `tunnel_start`/`tunnel_stop`/`tunnel_is_active` (frb/dart:ffi have no ambient runtime, so we `block_on`). |
| `src/c_api.rs` | `#[no_mangle]` C ABI (`mstream_iroh_*`) consumed by `dart:ffi`. |
| `src/bin/client.rs` | dev CLI; drives the same `ffi` path the app uses. |
| `interop/harness.mjs` | stands up the PR #643 server side and drives the compiled Rust client through real HTTP. |
| `build-android.sh` | cross-compiles + stages the `.so` into the app's `jniLibs`. |

Dart side: `../../lib/native/iroh_tunnel.dart` (FFI wrapper; `IrohTunnel.instance.start(code)` → port).

## Binding choice: C ABI + `dart:ffi` (not flutter_rust_bridge)

The surface is tiny (start / stop / is-active / last-error), so a hand-written C ABI consumed via `dart:ffi` is lighter than an frb codegen step in the build/CI — one `.so` plus a small Dart wrapper. frb remains an option if a richer or streaming surface is ever needed.

## Run the interop test (desktop, no device needed)

```sh
cd interop && npm install          # @number0/iroh@next (v1)
cd .. && cargo build               # builds the dev client binary
node interop/harness.mjs           # Rust client ⇆ JS server; asserts JSON + Range + concurrency
```

## Build for Android

```sh
rustup target add aarch64-linux-android x86_64-linux-android
cargo install cargo-ndk
export ANDROID_NDK_HOME=.../Android/Sdk/ndk/28.2.13676358
./build-android.sh                 # stages libiroh_tunnel.so into ../../android/app/src/main/jniLibs/<abi>/
```

Real shipped `.so` size (release, `opt-level=z` + thin-LTO + stripped, API 26):

| ABI | size |
|---|---|
| arm64-v8a | **9.48 MB** (9,943,624 bytes) |
| x86_64 | 11.02 MB (11,551,544 bytes) — emulators only |

With Play app-bundle ABI splits, an arm64 device downloads only its own slice (~9.5 MB). iroh **core only** — no blobs/docs/gossip/rpc (the full off-the-shelf FFI is 31 MB).

## On-device acceptance (the remaining M1 step)

1. Run a real mStream with PR #643, set `iroh.enabled`, copy the pairing code from the admin **Remote Access** panel.
2. `./build-android.sh` to stage the `.so`, then `flutter build apk --flavor full` (or `play`).
3. From a throwaway call: `final port = await IrohTunnel.instance.start('<code>');` then GET `http://127.0.0.1:$port/api/` → expect 200.

(M2 wires this into the `Server` model + QR-scan add-server UI; M3 adds lifecycle/hardening.)
