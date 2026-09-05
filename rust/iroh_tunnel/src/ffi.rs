//! Dart/Android entry points for the tunnel.
//!
//! flutter_rust_bridge (and the dev CLI) call Rust from threads that have NO
//! ambient Tokio runtime, while [`crate::connect_tunnel`] and its accept loop
//! need one. So this module owns a process-global multi-thread runtime and drives
//! the async core via `block_on`. Running [`Tunnel`]s are held here, keyed by an
//! app-chosen id (the app uses the server's identity — its pairing code, or a
//! federated peer's localname), so each loop survives after `start` returns and
//! `stop` can close its tunnel gracefully. One tunnel per key; distinct keys run
//! concurrently, each on its own loopback port with its own supervisor.
//!
//! The key is deliberately NOT the credential: a federated peer's guest token is
//! refreshed daily ([`tunnel_set_credential`]) and the tunnel — port, token,
//! queued URLs — must outlive the credential it was started with.
//!
//! These functions are the stable surface the C ABI wraps (they are
//! deliberately synchronous, `Send`-safe, and use `String` errors).

use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

use crate::{connect_tunnel, Tunnel, PATH_UNKNOWN, STATUS_CONNECTED, STATUS_DOWN};

/// Bumped when the C ABI changes shape. v1: one global tunnel. v2: tunnels
/// keyed by an app-chosen id, plus `set_credential`. The Dart side probes
/// `mstream_iroh_abi_version` and refuses a binary older than it expects.
pub const ABI_VERSION: i32 = 2;

static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static TUNNELS: Mutex<BTreeMap<String, Tunnel>> = Mutex::new(BTreeMap::new());

fn rt() -> &'static tokio::runtime::Runtime {
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to build tunnel Tokio runtime")
    })
}

/// Start the tunnel for `key` from a code (a Quick Connect pairing code or a
/// federation guest ticket). Returns the loopback port the app should use as
/// that server's base URL (`http://127.0.0.1:<port>`). Pass `local_port = 0`
/// to let the OS pick. Idempotent per key: if this key's tunnel is already
/// running, returns its existing port.
pub fn tunnel_start(key: String, code: String, local_port: u16) -> Result<u16, String> {
    // Fast path: already running. Hold the lock only to peek — never during connect.
    if let Some(port) = TUNNELS.lock().unwrap().get(&key).map(|t| t.local_port) {
        return Ok(port);
    }
    // Dial WITHOUT holding the global lock. connect_tunnel can take tens of seconds
    // (relay warmup + handshake); status / path-kind / network-change are polled from
    // the app's UI isolate and lock this same mutex — holding it across the connect
    // froze the app (ANR). So connect first, then lock briefly to store.
    let tunnel = rt()
        .block_on(connect_tunnel(&code, local_port))
        .map_err(|e| format!("{e:#}"))?;
    let port = tunnel.local_port;
    let mut guard = TUNNELS.lock().unwrap();
    match guard.get(&key) {
        // Lost a race (another start stored this key while we dialed): keep theirs
        // and tear ours down in the background.
        Some(existing) => {
            let existing_port = existing.local_port;
            drop(guard);
            tunnel.begin_shutdown(rt());
            Ok(existing_port)
        }
        None => {
            guard.insert(key, tunnel);
            Ok(port)
        }
    }
}

/// Stop the tunnel for `key` (graceful). Safe to call when it isn't running.
///
/// The app's `stop()` is synchronous on the UI isolate, so this must NOT block:
/// [`Tunnel::begin_shutdown`] hands the bounded in-flight drain + close to the
/// runtime and returns immediately.
pub fn tunnel_stop(key: &str) {
    let taken = TUNNELS.lock().unwrap().remove(key);
    if let Some(t) = taken {
        t.begin_shutdown(rt());
    }
}

/// This key's tunnel loopback auth token (`__lt=<token>`), or None when it isn't
/// running. The app appends it to every loopback URL so other apps on the device
/// can't use the proxy.
pub fn tunnel_local_token(key: &str) -> Option<String> {
    TUNNELS.lock().unwrap().get(key).map(|t| t.local_token())
}

/// This key's tunnel selected-path kind (one of the `PATH_*` codes);
/// `PATH_UNKNOWN` when it isn't running or no path is selected yet.
pub fn tunnel_path_kind(key: &str) -> u8 {
    TUNNELS
        .lock()
        .unwrap()
        .get(key)
        .map(|t| t.path_kind())
        .unwrap_or(PATH_UNKNOWN)
}

/// This key's tunnel status (one of the `STATUS_*` codes); `STATUS_DOWN` when it
/// isn't running.
pub fn tunnel_status(key: &str) -> u8 {
    TUNNELS
        .lock()
        .unwrap()
        .get(key)
        .map(|t| t.status())
        .unwrap_or(STATUS_DOWN)
}

/// Whether this key's tunnel is currently CONNECTED — a real health check, not
/// mere presence (a reconnecting/rejected/dead tunnel reports false).
pub fn tunnel_is_active(key: &str) -> bool {
    tunnel_status(key) == STATUS_CONNECTED
}

/// Nudge iroh that the network may have changed (Android can't self-detect), so
/// EVERY running tunnel re-homes its relay and re-probes paths promptly. No-op
/// when none are running.
pub fn tunnel_network_changed() {
    let guard = TUNNELS.lock().unwrap();
    for t in guard.values() {
        // Fire-and-forget on the runtime: do NOT block_on under the lock (the UI
        // isolate polls status and must not stall behind a network re-probe).
        t.nudge_network(rt());
    }
}

/// Reconnect this key's tunnel in place (same endpoint / port / token): re-bind
/// the loopback listener and close the current connection so the supervisor
/// re-dials at once. Fire-and-forget; no-op when it isn't running.
pub fn tunnel_force_reconnect(key: &str) {
    let guard = TUNNELS.lock().unwrap();
    if let Some(t) = guard.get(key) {
        t.force_reconnect(rt());
    }
}

/// Swap the credential this key's tunnel dials with, in place — see
/// [`Tunnel::set_credential`]. Errors when no such tunnel is running, the code
/// does not parse, or it names a different server / kind.
pub fn tunnel_set_credential(key: &str, code: &str) -> Result<(), String> {
    let guard = TUNNELS.lock().unwrap();
    match guard.get(key) {
        Some(t) => t.set_credential(code, rt()).map_err(|e| format!("{e:#}")),
        None => Err(format!("no tunnel is running for '{key}'")),
    }
}

/// Native events for this key's tunnel since the last call (one per line), or
/// None when nothing happened / it isn't running. Cheap: the ring is drained
/// under a short lock.
pub fn tunnel_drain_events(key: &str) -> Option<String> {
    TUNNELS.lock().unwrap().get(key).and_then(|t| t.drain_events())
}

/// Whether this key's tunnel has a home relay connected: 1 = yes, 0 = no, -1 =
/// not running (unknown). The app's reconnect watchdog reads this to tell a dead
/// zone from a supervisor that is failing with the relay reachable.
pub fn tunnel_relay_online(key: &str) -> i32 {
    match TUNNELS.lock().unwrap().get(key) {
        Some(t) => i32::from(t.relay_online()),
        None => -1,
    }
}

/// How many tunnels are running (diagnostics).
pub fn tunnel_count() -> usize {
    TUNNELS.lock().unwrap().len()
}
