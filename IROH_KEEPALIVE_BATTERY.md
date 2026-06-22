# iroh tunnel — keepalive & battery policy

How the iroh remote-access tunnel (`rust/iroh_tunnel/`) behaves with respect to
QUIC keepalive, idle timeouts, and Android battery — and why the client sets **no
custom transport config**. Verified against the pinned **iroh 1.0.0** source.

## TL;DR

- **Keepalive is already on by default (5 s).** We do *not* enable or tune it.
- A silently-dead path is detected on its own, so the reconnect supervisor wakes
  unaided — typically **~15 s** (direct path) to **~30 s** (relay path) after the
  network drops with no clean close.
- `connect_tunnel` keeps using `Endpoint::bind(presets::N0)` + `endpoint.connect(addr, ALPN)`
  with **no `ConnectOptions` / `TransportConfig` override**.
- Background battery cost is effectively zero: when idle/backgrounded without a
  foreground service, Android Doze suspends the process, so keepalive stops too.

## Defaults that apply to our connection

Under `presets::N0` + `endpoint.connect(...)`, the connection uses iroh's default
`QuicTransportConfig` (the N0 preset does not touch transport config):

| Setting | Value | Source |
| --- | --- | --- |
| connection `keep_alive_interval` | **5 s** | `iroh-1.0.0/src/endpoint/quic.rs:156-158` |
| connection `max_idle_timeout` | **30 s** (negotiated to `min(local, peer)`) | `quic.rs`; noq-proto `connection/mod.rs:7736-7743` |
| per-path `keep_alive_interval` | **5 s** | `quic.rs:156-158` |
| per-path `max_idle_timeout` (IP/direct) | **15 s** | `src/socket.rs:117` (`PATH_MAX_IDLE_TIMEOUT`) |
| per-path `max_idle_timeout` (relay) | **30 s** | `src/socket.rs:129` (`RELAY_PATH_MAX_IDLE_TIMEOUT`) |

Because keepalive is on, PING frames go out every 5 s even with no app traffic.

## How a dead path is detected (and the supervisor wakes)

On a silent path death (network change, no FIN/RST) the PINGs go unacked and two
timers race:

1. The **per-path idle timeout** abandons the dead path (15 s direct, 30 s relay).
   When the last usable path is abandoned the whole connection closes
   (noq-proto `transport.rs:404-405`).
2. The **connection-level negotiated idle timeout** (≤ 30 s) closes with
   `ConnectionError::TimedOut` (`connection/mod.rs:7465`).

Either way `conn.closed()` (lib.rs `supervise`) resolves on its own — **~15 s** on
a direct path, **up to ~30 s** if the surviving path was the relay — and the
supervisor re-dials. No keepalive tuning is needed for this to work.

**Caveat:** this only advances while the process (and the Tokio runtime + iroh
background tasks) is scheduled. If Android suspends the process (Doze / App
Standby, no foreground service), the QUIC timers and `closed()` freeze until the
process runs again.

## Why no custom keepalive

- Setting `keep_alive_interval` to 5 s explicitly is a **no-op** (it's already the
  default); lower only burns more radio wake-ups / battery for faster detection we
  don't need.
- The library bounds the per-path timers anyway: a path `keep_alive` above 5 s is
  ignored with a warning, and a path `max_idle` above 15 s is clamped
  (`quic.rs:491-520`). **Never** set `max_idle_timeout` to `None`/0 — iroh's own
  docs warn it can hang futures forever on a malfunctioning path (`quic.rs:191-193`).
- App-resume recovery does **not** depend on a keepalive having held the connection
  open across a suspend: on resume / connectivity change the app calls
  `Endpoint::network_change()` + a verify-rebuild (`ServerManager.handleNetworkChange`),
  which re-homes the relay and re-probes paths.

## Battery

- A keepalive costs anything only while a connection is **actually open and the
  process is scheduled**. The 5 s PING is a few KB/min — negligible as data, but on
  cellular each radio wake can hold the modem in a high-power RRC state (the real
  cost of frequent keepalives on mobile).
- **During playback** an `audio_service` foreground service keeps the process (and
  iroh) scheduled, so keepalive runs and holds the path warm — desirable, and
  dwarfed by the audio stream itself.
- **Idle / backgrounded without a foreground service**, Doze suspends the runtime,
  so keepalive stops and there is ~no background drain. Recovery on the next resume
  rides `network_change()` + verify-rebuild, not a held-open connection.

## If we ever do want a knob

iroh 1.0.0 exposes per-connection transport config, but **not** via `Endpoint::connect`
(it hardcodes `Default::default()`, `endpoint.rs:1048`). Two supported routes:

- **Per-dial:** switch `dial_and_handshake` from `connect()` to
  `connect_with_opts(addr, alpn, ConnectOptions::new().with_transport_config(cfg))`
  (`endpoint.rs:1080,1771`), then await the returned `Connecting` once more.
- **Endpoint-wide (preferred):** `Endpoint::builder(presets::N0).transport_config(cfg).bind()`
  (`endpoint.rs:669`) so the supervisor's re-dials inherit it without threading
  `ConnectOptions` through `dial_and_handshake`.

Build `cfg` with the public `QuicTransportConfig::builder()` (`quic.rs:134`), which
**starts from iroh's tuned defaults** (multipath, NAT traversal, 5 s/15 s timers),
so overriding one field does not disable holepunching.
