//! Dart/Android entry points for the tunnel.
//!
//! flutter_rust_bridge (and the dev CLI) call Rust from threads that have NO
//! ambient Tokio runtime, while [`crate::connect_tunnel`] and its accept loop
//! need one. So this module owns a process-global multi-thread runtime and drives
//! the async core via `block_on`. Running [`Tunnel`]s are held here, keyed by
//! their pairing code (the app's durable server identity), so each loop survives
//! after `start` returns and `stop` can close its tunnel gracefully. One tunnel
//! per pairing code; distinct codes run concurrently, each on its own loopback
//! port.
//!
//! These functions are the stable surface the flutter_rust_bridge codegen wraps
//! (they are deliberately synchronous, `Send`-safe, and use `String` errors).

use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

use crate::{connect_tunnel, Tunnel, PATH_UNKNOWN, STATUS_CONNECTED, STATUS_DOWN};

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

/// Start the tunnel for a composite pairing code. Returns the loopback port the
/// app should use as that server's base URL (`http://127.0.0.1:<port>`). Pass
/// `local_port = 0` to let the OS pick. Idempotent per code: if this code's
/// tunnel is already running, returns its existing port.
pub fn tunnel_start(pairing_code: String, local_port: u16) -> Result<u16, String> {
    // Fast path: already running. Hold the lock only to peek — never during connect.
    if let Some(port) = TUNNELS
        .lock()
        .unwrap()
        .get(&pairing_code)
        .map(|t| t.local_port)
    {
        return Ok(port);
    }
    // Dial WITHOUT holding the global lock. connect_tunnel can take tens of seconds
    // (relay warmup + handshake); status / path-kind / network-change are polled from
    // the app's UI isolate and lock this same mutex — holding it across the connect
    // froze the app (ANR). So connect first, then lock briefly to store.
    let tunnel = rt()
        .block_on(connect_tunnel(&pairing_code, local_port))
        .map_err(|e| format!("{e:#}"))?;
    let port = tunnel.local_port;
    let mut guard = TUNNELS.lock().unwrap();
    match guard.get(&pairing_code) {
        // Lost a race (another start stored this code while we dialed): keep theirs
        // and tear ours down in the background.
        Some(existing) => {
            let existing_port = existing.local_port;
            drop(guard);
            tunnel.begin_shutdown(rt());
            Ok(existing_port)
        }
        None => {
            guard.insert(pairing_code, tunnel);
            Ok(port)
        }
    }
}

/// Stop the tunnel for `pairing_code` (graceful). Safe to call when it isn't
/// running.
///
/// The app's `stop()` is synchronous on the UI isolate, so this must NOT block:
/// [`Tunnel::begin_shutdown`] hands the bounded in-flight drain + close to the
/// runtime and returns immediately.
pub fn tunnel_stop(pairing_code: &str) {
    let taken = TUNNELS.lock().unwrap().remove(pairing_code);
    if let Some(t) = taken {
        t.begin_shutdown(rt());
    }
}

/// This code's tunnel loopback auth token (`__lt=<token>`), or None when it isn't
/// running. The app appends it to every loopback URL so other apps on the device
/// can't use the proxy.
pub fn tunnel_local_token(pairing_code: &str) -> Option<String> {
    TUNNELS
        .lock()
        .unwrap()
        .get(pairing_code)
        .map(|t| t.local_token())
}

/// This code's tunnel selected-path kind (one of the `PATH_*` codes);
/// `PATH_UNKNOWN` when it isn't running or no path is selected yet.
pub fn tunnel_path_kind(pairing_code: &str) -> u8 {
    TUNNELS
        .lock()
        .unwrap()
        .get(pairing_code)
        .map(|t| t.path_kind())
        .unwrap_or(PATH_UNKNOWN)
}

/// This code's tunnel status (one of the `STATUS_*` codes); `STATUS_DOWN` when it
/// isn't running.
pub fn tunnel_status(pairing_code: &str) -> u8 {
    TUNNELS
        .lock()
        .unwrap()
        .get(pairing_code)
        .map(|t| t.status())
        .unwrap_or(STATUS_DOWN)
}

/// Whether this code's tunnel is currently CONNECTED — a real health check, not
/// mere presence (a reconnecting/rejected/dead tunnel reports false).
pub fn tunnel_is_active(pairing_code: &str) -> bool {
    tunnel_status(pairing_code) == STATUS_CONNECTED
}

/// Nudge iroh that the network may have changed (Android can't self-detect), so
/// every running tunnel re-homes its relay and re-probes paths promptly. No-op
/// when none are running.
pub fn tunnel_network_changed() {
    let guard = TUNNELS.lock().unwrap();
    for t in guard.values() {
        // Fire-and-forget on the runtime: do NOT block_on under the lock (the UI
        // isolate polls status and must not stall behind a network re-probe).
        t.nudge_network(rt());
    }
}
