//! Dart/Android entry points for the tunnel.
//!
//! flutter_rust_bridge (and the dev CLI) call Rust from threads that have NO
//! ambient Tokio runtime, while [`crate::connect_tunnel`] and its accept loop
//! need one. So this module owns a process-global multi-thread runtime and drives
//! the async core via `block_on`. The running [`Tunnel`] is held here so the loop
//! survives after `start` returns and `stop` can close it gracefully.
//!
//! These functions are the stable surface the flutter_rust_bridge codegen wraps
//! (they are deliberately synchronous, `Send`-safe, and use `String` errors).

use std::sync::{Mutex, OnceLock};

use crate::{connect_tunnel, Tunnel, PATH_UNKNOWN, STATUS_CONNECTED, STATUS_DOWN};

static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static TUNNEL: Mutex<Option<Tunnel>> = Mutex::new(None);

fn rt() -> &'static tokio::runtime::Runtime {
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to build tunnel Tokio runtime")
    })
}

/// Start the tunnel from a composite pairing code. Returns the loopback port the
/// app should use as its server base URL (`http://127.0.0.1:<port>`). Pass
/// `local_port = 0` to let the OS pick. Idempotent: if a tunnel is already
/// running, returns its existing port.
pub fn tunnel_start(pairing_code: String, local_port: u16) -> Result<u16, String> {
    // Fast path: already running. Hold the lock only to peek — never during connect.
    if let Some(port) = TUNNEL.lock().unwrap().as_ref().map(|t| t.local_port) {
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
    let mut guard = TUNNEL.lock().unwrap();
    match guard.as_ref() {
        // Lost a race (another start stored one while we dialed): keep theirs and
        // tear ours down in the background.
        Some(existing) => {
            let existing_port = existing.local_port;
            drop(guard);
            tunnel.begin_shutdown(rt());
            Ok(existing_port)
        }
        None => {
            *guard = Some(tunnel);
            Ok(port)
        }
    }
}

/// Stop the tunnel (graceful). Safe to call when nothing is running.
///
/// The app's `stop()` is synchronous on the UI isolate, so this must NOT block:
/// [`Tunnel::begin_shutdown`] hands the bounded in-flight drain + close to the
/// runtime and returns immediately.
pub fn tunnel_stop() {
    let taken = TUNNEL.lock().unwrap().take();
    if let Some(t) = taken {
        t.begin_shutdown(rt());
    }
}

/// Current selected-path kind (one of the `PATH_*` codes); `PATH_UNKNOWN` when
/// nothing is running or no path is selected yet.
pub fn tunnel_path_kind() -> u8 {
    TUNNEL
        .lock()
        .unwrap()
        .as_ref()
        .map(|t| t.path_kind())
        .unwrap_or(PATH_UNKNOWN)
}

/// Current tunnel status (one of the `STATUS_*` codes); `STATUS_DOWN` when none.
pub fn tunnel_status() -> u8 {
    TUNNEL
        .lock()
        .unwrap()
        .as_ref()
        .map(|t| t.status())
        .unwrap_or(STATUS_DOWN)
}

/// Whether the tunnel is currently CONNECTED — a real health check, not mere
/// presence (a reconnecting/rejected/dead tunnel reports false).
pub fn tunnel_is_active() -> bool {
    tunnel_status() == STATUS_CONNECTED
}

/// Nudge iroh that the network may have changed (Android can't self-detect), so
/// it re-homes the relay and re-probes paths promptly. No-op when not running.
pub fn tunnel_network_changed() {
    let guard = TUNNEL.lock().unwrap();
    if let Some(t) = guard.as_ref() {
        // Fire-and-forget on the runtime: do NOT block_on under the lock (the UI
        // isolate polls status and must not stall behind a network re-probe).
        t.nudge_network(rt());
    }
}
