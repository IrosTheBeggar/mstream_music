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

use crate::{connect_tunnel, Tunnel};

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
    let mut guard = TUNNEL.lock().unwrap();
    if let Some(t) = guard.as_ref() {
        return Ok(t.local_port);
    }
    let tunnel = rt()
        .block_on(connect_tunnel(&pairing_code, local_port))
        .map_err(|e| format!("{e:#}"))?;
    let port = tunnel.local_port;
    *guard = Some(tunnel);
    Ok(port)
}

/// Stop the tunnel (graceful). Safe to call when nothing is running.
pub fn tunnel_stop() {
    let taken = TUNNEL.lock().unwrap().take();
    if let Some(t) = taken {
        rt().block_on(t.shutdown());
    }
}

/// Whether a tunnel is currently active.
pub fn tunnel_is_active() -> bool {
    TUNNEL.lock().unwrap().is_some()
}
