# iroh P2P Transport — Android App Implementation Plan

**Status:** server side **DONE** — mStream [PR #643](https://github.com/IrosTheBeggar/mStream/pull/643) "feat(iroh): opt-in P2P remote-access tunnel (Phase 2A)". This plan covers the **Android client** ("Phase 2B"). · **Feasibility:** confirmed by Phase 0 spikes + the shipped server. · Updated 2026-06-19.

Add [iroh](https://www.iroh.computer/) as an **alternative way for the app to reach an mStream server** — dial the server by its cryptographic EndpointId, no port-forwarding / DDNS / public IP / reverse proxy, and no self-signed-TLS friction. It's an *addition*: HTTP(S) stays the default. The **server half already exists and defines the protocol** — the app must match it exactly.

---

## 1. What PR #643 ships (the server half)

An opt-in Iroh tunnel in mStream (`src/state/iroh.js`, admin "Remote Access" panel). Confirmed by reading the PR at `9ca4b6b`:

- **Same tunnel shape my plan proposed:** binds an Iroh endpoint, accepts QUIC on a custom ALPN, and proxies **one bi-stream ⇆ one TCP connection** to the local mStream HTTP server. Full HTTP semantics preserved (keep-alive, **range/seek**, parallel requests). mStream's normal JWT auth wall still gates the API *inside* the tunnel.
- **Opt-in** `iroh.enabled` config (default off). `secretKey` (→ stable EndpointId) and `connectSecret` are auto-generated and persisted like `secret`/`subsonicSecret`.
- **`@number0/iroh` is an optionalDependency, lazy-loaded** — servers on platforms without a prebuilt binary (e.g. Intel macOS) boot normally with the feature off.
- **QR pairing** in the admin panel (live enable/disable, copy-code, **rotate-secret**).
- **Reference client `scripts/mstream-iroh-client.mjs`** — a standalone JS client that dials the tunnel and exposes the server at `http://127.0.0.1:<port>`. **This is the canonical behavioral spec for our shim** — the Rust shim is a 1:1 port of it.

> Net effect: my original **M1 (server acceptor) is complete.** What's left is the Android client, built to the contract below.

---

## 2. Protocol contract — FROZEN by PR #643 (the app must match byte-for-byte)

1. **Pairing code** (the QR contents) = a **versioned envelope** `mstr<V>:<base64url(JSON{ t: <EndpointTicket>, s: <connectSecret base64> })>` (spec: `docs/iroh-pairing-code.md` in PR #643). Schema is currently **v1** (`mstr1:`); an un-prefixed body is a legacy code → implicit v1; a version newer than the client supports is rejected with an "update the app" error. `t`/`s` are stable across versions; `secret` is **32 bytes** (base64-decoded). Reject malformed/missing-field payloads.
2. **ALPN** = UTF-8 bytes of `"mstream/tunnel/2"` (note: **v2**). Both ends must present identical bytes; the version bumps if framing changes.
3. **Connect:**
   - Bind an **ephemeral** client endpoint (`Endpoint::bind` with no secret key — the server does *not* allowlist client identity; the shared secret is the gate).
   - **Wait for our home relay before dialing** (`endpoint.online()` bounded to ~8 s). Skipping this can reset the first stream on a cold cross-network path.
   - `ticket → EndpointAddr`, then `connect(addr, ALPN)` with a ~25 s timeout.
4. **Handshake** (on the **first** bi-stream, before any HTTP):
   - `open_bi`; `send.write_all(<32 secret bytes>)`; `send.finish()`.
   - Read the reply (small limit); it must be ASCII **`"OK"`**. Anything else (e.g. `"NO"`) ⇒ secret wrong/rotated ⇒ **fail and prompt re-pair**. (Server compares constant-time.)
5. **Tunnel:** run a localhost TCP listener. **Per inbound TCP connection → one new `open_bi`**, then full-duplex pump:
   - `recv.read(64 KiB)` loop; an **empty read == clean EOF** → half-close the socket (don't destroy; lets in-flight responses drain).
   - socket→`send.write_all(chunk)`; on socket end → `send.finish()`.
   - One persistent `Connection`, many bi-streams (QUIC multiplexing). On either-direction error, tear down both halves.
6. **Rotation/staleness:** the admin can rotate `connectSecret` (old codes then fail the handshake) and the relay/direct addrs in the ticket can age. App must handle handshake-reject and connect-timeout by surfacing a clear "re-pair" path. (EndpointId is stable, so discovery can still resolve a moved server.)

A passing server test tunnels a literal `GET /probe HTTP/1.0` and gets a `200` with the path echoed — i.e. the contract is exactly "plain HTTP over the pipe," same as our Phase 0 PoC.

---

## 3. Why the app side is still real work

- **Android can't run the JS reference client.** The app is Flutter/Dart and there's **no Dart iroh binding**, so we need native iroh. Two options:
  - **(chosen) thin Rust shim** depending on `iroh` **core only**, exposed over a small **C ABI consumed by `dart:ffi`** (the surface is just start/stop/is-active/last-error — a hand-written C ABI is lighter than a flutter_rust_bridge codegen step in the build/CI; frb stays an option if a richer/async surface is ever needed). Phase 0 measured **arm64-v8a 8.3 MB / x86_64 9.8 MB** (stripped), links at **API 26** (current `minSdk`, no bump), crypto backend **ring** (cross-compiles cleanly via `cargo-ndk --platform 26`).
  - **(alternative) iroh-ffi Kotlin binding** (`v1.0.0` tag) with the tunnel logic in Kotlin. Less Rust glue, but it's the full FFI (~31 MB, bundles blobs/docs/gossip) and still a self-built `.so` (no Maven artifact). Rejected on size unless trimmed.
- **The tunnel insight is unchanged:** because the pipe carries plain HTTP, pointing the app's base URL at `http://127.0.0.1:<localPort>` means **zero changes to `lib/singletons/api.dart`, the just_audio/ExoPlayer streaming path, or album art** — and the self-signed-TLS path (`InsecureTls`) is unnecessary on the iroh route.

---

## 4. Architecture (app)

### 4.1 Native shim (Rust, `iroh` core) — a 1:1 port of `mstream-iroh-client.mjs` ✅ built
Lives in `rust/iroh_tunnel/` (`src/lib.rs` async core, `src/ffi.rs` owned Tokio runtime, `src/c_api.rs` C ABI). C ABI surface (consumed via `dart:ffi` in `lib/native/iroh_tunnel.dart`):
- `mstream_iroh_start(pairing_code, local_port) -> port` — parse the composite code, bind ephemeral endpoint, `online()`, connect on `mstream/tunnel/2`, **do the secret handshake**, start the localhost TCP listener, return the port.
- `mstream_iroh_stop()`, `mstream_iroh_is_active()`, `mstream_iroh_last_error()`.
- (status stream — `connecting | online | handshaking | connected | rejected | error` — deferred to M3 UI; not needed for the M1 connect proof.)

Internals map directly to the contract (§2): `Endpoint::bind`, ticket parse → `EndpointAddr`, `connect`, `open_bi`, `write_all`/`finish`, `read`/`read_to_end`, per-socket `open_bi` + byte pumps. *Verify during impl:* the Rust ticket type for `t` (JS uses `EndpointTicket.fromString(t).endpointAddr()`; confirm the iroh-rs 1.0 equivalent — `iroh`/`iroh_base` ticket type).

Build for **arm64-v8a + x86_64** with `cargo-ndk --platform 26`; package `.so` into `jniLibs`.

### 4.2 Connection model
- `lib/objects/server.dart`: add an optional `irohPairingCode` field (stores the whole composite code — it's a **credential**, treat like `jwt`/`password`); migrate `servers.json`.
- One `effectiveBaseUrl` accessor: iroh server → `http://127.0.0.1:<localPort>` from the shim; else `server.url`. **Everything else reads this and is unchanged.** (Audit `api.dart` / `lib/util/stream_url.dart` for direct `server.url` reads and route them through it.)

### 4.3 Pairing + sign-in UX (add-server "iroh" tab)
The server shows a **QR** in its admin "Remote Access" panel; the phone is the natural scanner. The iroh tab in `lib/screens/add_server.dart` flows:
1. **Scan QR** (`mobile_scanner`, camera-permission gated) or **Paste code**.
2. **Test connection** — `IrohTunnel.start(code)` opens the tunnel and fetches `/api/` through it (proves the tunnel + shows the server version). On handshake-reject/timeout, tell the user the code may be **rotated/stale → re-pair**.
3. **Sign in** *(revealed once the test passes)* — username/password, plus a public-access toggle for unauthenticated servers, mirroring the standard tab. Authenticate by POSTing `/api/v1/auth/login` **through the tunnel** (`http://127.0.0.1:<port>/…`) to get the JWT. Skip the self-signed-TLS controls (not needed on iroh).
4. **Save** — persist a `Server` carrying the `irohPairingCode` + JWT (and storage/download settings, like the standard tab). The saved server has no fixed remote URL; its base URL is resolved at runtime via `effectiveBaseUrl` (§4.2) once the tunnel starts.

### 4.4 Lifecycle
Keep the endpoint + proxy alive during background playback via the existing `audio_service` foreground service. Tear down on disconnect; reconnect on resume.

---

## 5. Milestones (app only — server M1 is done)

### M1 — Shim + binding + on-device connect **against the live PR #643 server** *(retires the last unknown)*
- ✅ `iroh` core-only Rust crate implementing the full §2 contract (incl. handshake) — `rust/iroh_tunnel/`.
- ✅ **Interop proven on desktop:** the Rust client tunnels JSON + a Range/seek (206) request + concurrency against a faithful replica of the PR #643 server (`rust/iroh_tunnel/interop/harness.mjs`).
- ✅ C ABI (`src/c_api.rs`) + Dart FFI binding (`lib/native/iroh_tunnel.dart`); cross-compiles for both ABIs (`build-android.sh`).
- ✅ **Device-verified (2026-06-21, Galaxy S25):** scanning the server's QR + Test connection completed the handshake and returned the server version through the tunnel. Also fixed an Android-only crash — iroh needs the app `Context` via `ndk_context` (now registered from `IrohNative`/`MainActivity` at startup) and the C ABI is panic-guarded (`catch_unwind`).

### M2 — Connection model + QR pairing UI + sign-in + playback
- ✅ QR-scan + paste + **Test connection** (shows the server version through the tunnel).
- **Sign-in form** revealed after a passing test → login (username/password or public-access) **through the tunnel** → JWT. *(this slice)*
- `Server.irohPairingCode` + a connection-type marker + `servers.json` migration; **`effectiveBaseUrl` routing** so the whole API + streaming go through the tunnel; **save** the iroh server; start the tunnel when it becomes the active server. *(this slice)*
- **Accept:** add an iroh server (scan → test → sign in → save), browse the library, and **play + seek a track** end-to-end; no code path reads `server.url` directly on the iroh route.

### M3 — Hardening (tiered)
**Tier 1 — self-healing tunnel ✅ (built; desktop-verified, device check pending):**
- Shim reconnects itself: a supervisor watches the live `Connection` and, on death, re-dials on the SAME endpoint (`online`→`connect`→re-handshake) with capped backoff, swapping the connection in place — the loopback port stays stable, so queue URLs survive. Bridges retry `open_bi` briefly so an in-flight request rides the reconnect. Interop forced-reconnect test passes.
- Honest health: `is_active`/`status` now reflect the real `Connection` state (`connecting|connected|reconnecting|rejected|down`), exposed over the C ABI + `IrohTunnelStatus` in Dart.
- Android network nudge: `mstream_iroh_network_changed()` → `Endpoint::network_change()` (iroh can't self-detect on Android), driven by `connectivity_plus` + the app-resume hook; `ServerManager.handleNetworkChange()`. `ensureActiveTunnel({verify})` consults real health + an in-flight guard.

**Tier 2 — recovery UX ✅ (built; `flutter analyze` clean + APK builds, device check pending):**
- Status banner (`main.dart` `_tunnelBanner`) driven by a polled `ServerManager.tunnelStatusStream`: "Reconnecting…" while the supervisor re-dials, "Disconnected — Retry" when hard-down, "Server pairing changed — Re-pair" on `rejected`.
- Reconnect-then-retry in `makeServerCall`: iroh requests are time-bounded and, on a connection error, `awaitTunnelReady()` then retry once.
- just_audio error-stream recovery (`audio_stuff._onPlaybackError`): on an iroh stream error, wait for the tunnel, re-seed the source, resume at position (debounced).
- In-app **re-pair**: `iroh_repair_sheet` (paste/scan a fresh code) → `ServerManager.repairIrohPairingCode()` restarts the tunnel. QR scanner extracted to the shared `widgets/iroh_scanner.dart` (reused by add-server + re-pair).

**Tier 3 — polish & validation ✅ (built; `cargo test` + interop + `flutter analyze` green, APK builds, device check pending):**
- Direct-vs-relay indicator: the shim classifies the live connection's *selected* path via `Connection::paths()` (`is_selected`/`is_relay`) → `mstream_iroh_path_kind` (0/1/2) → Dart `IrohPathKind` + `ServerManager.pathKindStream` (sampled on the 2 s status poll). Surfaced as a "Connected via relay — slower path" banner strip (direct stays hidden, so everyday use is clean), a live Direct/Relay chip on the active iroh server's manage-servers tile (only while connected), and a "· direct / · via relay" suffix on the add-server Test result.
- Server-switch teardown drain: `Tunnel::begin_shutdown` is non-blocking (stop() is synchronous on the UI isolate) and hands the runtime a bounded drain — wait ≤ `DRAIN_TIMEOUT` (3 s) for in-flight bridges (`BridgeGuard` counts them), then a capped `endpoint.close()` — so a server switch doesn't abruptly cut an in-flight request.
- Keepalive/battery: **no custom transport config** — iroh's defaults (5 s keepalive, 15–30 s idle) already detect a dead path and self-heal, and backgrounded recovery rides the resume-time `network_change()` + verify-rebuild. Rationale + the (unused) knob recipe documented in [`IROH_KEEPALIVE_BATTERY.md`](IROH_KEEPALIVE_BATTERY.md).
- Adversarially reviewed (4 dimensions, every finding independently verified): **0 blockers/high**; 3 low/nit confirmed + fixed (capped `endpoint.close()` + accurate teardown docs; re-emit the server list on startup failover so the chip re-evaluates; chip gated to the connected state).

**Remaining: the true cross-network NAT test** (phone on cellular, server elsewhere) — the upcoming full test.

- **Accept:** rotate the server secret → clean re-pair prompt; playback survives backgrounding + a network blip; cross-network NAT works.

### M4 — Build/CI, flavors, release
- ✅ **`.so` delivery — commit the prebuilt `libiroh_tunnel.so`** (both ABIs), same model as `libprojectM-4.so`: the release runner (ubuntu-latest) has no Rust/NDK toolchain, so it ships the committed binary. `release.yml` guards that the `.so` is bundled in the full APK (arm64-v8a + x86_64) + play AAB (arm64-v8a); `build-android.sh` documents the rebuild-and-recommit rule. (commit 26fd618)
- Remaining: both `full`/`play` flavors within a size budget (+ fix the `--split-per-abi` AGP9 snag for a smaller arm64 sideload APK); `play` camera-permission rationale + Play **data-safety** note (relay routing); localize the iroh-tab/banner strings; user docs (enable on server → scan QR).
- **Accept:** signed builds of both flavors install, scan, connect; size delta documented.

---

## 6. Decisions

**Resolved:**
1. ✅ Server side → **upstream mStream** (shipped as PR #643).
2. ✅ Addressing → **composite QR pairing code** (`{t,s}`), not a bare ticket — *and it carries the connect secret*, so pairing is QR-first.

**Still open:**
3. **Relay:** n0 default relays vs. self-host for full independence (note v1 relay-support end-dates).
4. **`full`-flavor APK size:** universal (both ABIs ≈ +18 MB) vs per-ABI split (≈ +8.3 MB arm64). The Play bundle already splits per-ABI.
5. **iOS:** out of scope now; later needs the iroh Swift binding.
6. **Flutter QR scanner package** + camera-permission copy (and whether the `play` flavor's reduced-permission posture is OK with `CAMERA`).

## 7. Risks
- **Contract drift:** the app is pinned to `mstream/tunnel/2` + the composite/handshake. If the server bumps the ALPN version or changes framing, the app must follow. Track the server version.
- **`@number0/iroh` 1.0 is on the npm `next` tag** (server dep) and the feature is an optionalDependency — the user's server platform must have a prebuilt binary to enable it at all.
- **No prebuilt Maven** — we own a Rust build in CI (spike proved `cargo-ndk` + NDK 28.2 works).
- **On-device FFI path unproven** until the M1 device step (interop is proven on desktop; the `.so` cross-compiles, but the APK build + on-device `dart:ffi` load/handshake is the remaining check).
- **Relay readiness:** must `online()` before dialing (already in the contract) or the first stream can reset.

## 8. Contract & version pins (from PR #643 + spike)
| Thing | Value |
|---|---|
| ALPN | `mstream/tunnel/2` (UTF-8 bytes) |
| Pairing code | `mstr<V>:base64url(JSON{ t, s })` envelope (v1 current; bare body = legacy v1); secret = 32 bytes |
| Handshake | first bi-stream: write 32 secret bytes → expect ASCII `"OK"` |
| `iroh` Rust crate (shim) | `1` → 1.0.0 (core only); `Endpoint::bind` / `connect` / `open_bi` |
| `@number0/iroh` (server) | `next` → 1.0.0 |
| NDK / build | 28.2.13676358, `cargo-ndk --platform 26` (flag is `--platform`, not `-p`) |
| ABIs | arm64-v8a, x86_64 |
| crypto | ring 0.17 (cross-compiles to Android) |

## 9. Reference & reproduce
- **Behavioral spec:** mStream `scripts/mstream-iroh-client.mjs` (PR #643) — port to Rust verbatim. Server tunnel: `src/state/iroh.js`; config: `src/state/config.js` (`iroh.enabled`/`secretKey`/`connectSecret`); admin QR: `webapp/admin/`.
- **Manual end-to-end check before app work:** run a PR #643 server with `iroh.enabled`, then `node scripts/mstream-iroh-client.mjs <code>` and `curl http://127.0.0.1:3010/api/` — this is the exact behavior the shim reproduces on-device.
- **Android size probe:** minimal `cdylib` on `iroh="1"`+tokio, `opt-level="z"`/`lto="thin"`/`strip`/`panic="abort"`, `cargo ndk -t arm64-v8a -t x86_64 --platform 26 build --release`.
