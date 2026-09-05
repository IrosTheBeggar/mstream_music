//! C ABI for Dart FFI (`dart:ffi`).
//!
//! The tunnel's surface is small (start / stop / status / … per tunnel key,
//! plus a network nudge and the last-error slot), so a hand-written C ABI
//! consumed via `dart:ffi` is simpler and lighter than a flutter_rust_bridge
//! codegen step — no generator in the build, just one `.so` and a small Dart
//! wrapper.
//!
//! ABI v2 (see [`crate::ffi::ABI_VERSION`]): every per-tunnel entry point takes
//! the app's tunnel `key` first, and `mstream_iroh_set_credential` swaps a
//! running tunnel's credential in place. The Dart side probes
//! `mstream_iroh_abi_version` before anything else and refuses an older binary.
//!
//! Every entry point is **panic-guarded**: a panic in the tunnel/iroh code is
//! captured (message + location) into the last-error slot and returned as an
//! error, instead of unwinding across the `extern "C"` boundary and aborting the
//! whole app. On Android the message is also written to logcat (tag
//! `iroh_tunnel`).
//!
//! Threading: `mstream_iroh_start` blocks (relay warmup + dial, up to ~30s), so
//! Dart must call it off the UI isolate (e.g. `Isolate.run`). Everything else is
//! a short lock and safe on the UI isolate.

use std::ffi::{c_char, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::sync::{Mutex, OnceLock};

use crate::ffi::{
    tunnel_drain_events, tunnel_force_reconnect, tunnel_is_active, tunnel_local_token,
    tunnel_network_changed, tunnel_path_kind, tunnel_relay_online, tunnel_set_credential,
    tunnel_start, tunnel_status, tunnel_stop, ABI_VERSION,
};

static LAST_ERROR: Mutex<Option<CString>> = Mutex::new(None);
static LAST_PANIC: Mutex<Option<String>> = Mutex::new(None);
static PANIC_HOOK: OnceLock<()> = OnceLock::new();

fn set_last_error(msg: String) {
    log_android(&msg);
    *LAST_ERROR.lock().unwrap() = CString::new(msg).ok();
}

// Capture the panic message + location so `guard` can report it.
fn install_panic_hook() {
    PANIC_HOOK.get_or_init(|| {
        panic::set_hook(Box::new(|info| {
            let loc = info
                .location()
                .map(|l| format!("{}:{}", l.file(), l.line()))
                .unwrap_or_else(|| "?".into());
            let msg = info
                .payload()
                .downcast_ref::<&str>()
                .map(|s| s.to_string())
                .or_else(|| info.payload().downcast_ref::<String>().cloned())
                .unwrap_or_else(|| "panic".into());
            let full = format!("panic at {loc}: {msg}");
            log_android(&full);
            *LAST_PANIC.lock().unwrap() = Some(full);
        }));
    });
}

// Run an FFI body, turning a panic into a captured error + the `default` return.
fn guard<T>(default: T, body: impl FnOnce() -> T) -> T {
    install_panic_hook();
    match panic::catch_unwind(AssertUnwindSafe(body)) {
        Ok(v) => v,
        Err(_) => {
            let msg = LAST_PANIC
                .lock()
                .unwrap()
                .take()
                .unwrap_or_else(|| "panic in iroh tunnel".into());
            set_last_error(msg);
            default
        }
    }
}

// Read a NUL-terminated UTF-8 argument; None (with the last error set) when it
// is null or not UTF-8.
//
// # Safety
// `p` must be null or a valid NUL-terminated C string for the duration of the call.
unsafe fn string_arg(p: *const c_char, what: &str) -> Option<String> {
    if p.is_null() {
        set_last_error(format!("{what} is null"));
        return None;
    }
    match CStr::from_ptr(p).to_str() {
        Ok(s) => Some(s.to_owned()),
        Err(_) => {
            set_last_error(format!("{what} is not valid UTF-8"));
            None
        }
    }
}

// Hand a Rust string to Dart as a heap C string it must free with
// [`mstream_iroh_string_free`]; null for None.
fn string_out(s: Option<String>) -> *mut c_char {
    match s {
        Some(s) => CString::new(s)
            .map(|c| c.into_raw())
            .unwrap_or(std::ptr::null_mut()),
        None => std::ptr::null_mut(),
    }
}

/// The C ABI version this binary implements (see [`crate::ffi::ABI_VERSION`]).
/// Absent from v1 binaries — the Dart side treats a missing symbol as v1.
#[no_mangle]
pub extern "C" fn mstream_iroh_abi_version() -> i32 {
    ABI_VERSION
}

/// Start the tunnel for `key` from a NUL-terminated UTF-8 code (a Quick Connect
/// pairing code or a federation guest ticket). Returns the loopback port (> 0)
/// on success, or -1 on error — then call [`mstream_iroh_last_error`].
/// Idempotent per key (returns the existing port if that key is running).
///
/// # Safety
/// `key` and `code` must be valid NUL-terminated C strings for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_start(
    key: *const c_char,
    code: *const c_char,
    local_port: u16,
) -> i32 {
    let (Some(key), Some(code)) = (string_arg(key, "key"), string_arg(code, "code")) else {
        return -1;
    };
    guard(-1, move || match tunnel_start(key, code, local_port) {
        Ok(port) => port as i32,
        Err(e) => {
            set_last_error(e);
            -1
        }
    })
}

/// Stop the tunnel for `key` (graceful). Safe to call when it isn't running.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_stop(key: *const c_char) {
    if let Some(key) = string_arg(key, "key") {
        guard((), || tunnel_stop(&key));
    }
}

/// Whether the tunnel for `key` is currently CONNECTED.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_is_active(key: *const c_char) -> bool {
    match string_arg(key, "key") {
        Some(key) => guard(false, || tunnel_is_active(&key)),
        None => false,
    }
}

/// Current status of the tunnel for `key`: one of the STATUS_* codes
/// (0=connecting, 1=connected, 2=reconnecting, 3=rejected/re-pair, 4=down).
/// Mirrors lib.rs STATUS_* and the Dart `IrohTunnelStatus` enum. 4 when the
/// key has no tunnel.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_status(key: *const c_char) -> i32 {
    match string_arg(key, "key") {
        Some(key) => guard(crate::STATUS_DOWN as i32, || tunnel_status(&key) as i32),
        None => crate::STATUS_DOWN as i32,
    }
}

/// Tell every running tunnel the device network changed (call on connectivity
/// transitions — iroh can't self-detect them on Android).
#[no_mangle]
pub extern "C" fn mstream_iroh_network_changed() {
    guard((), tunnel_network_changed);
}

/// Current path kind of the tunnel for `key`: 0=unknown, 1=direct
/// (hole-punched), 2=relayed. Mirrors the PATH_* constants in lib.rs and the
/// Dart `IrohPathKind` enum.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_path_kind(key: *const c_char) -> i32 {
    match string_arg(key, "key") {
        Some(key) => guard(crate::PATH_UNKNOWN as i32, || tunnel_path_kind(&key) as i32),
        None => crate::PATH_UNKNOWN as i32,
    }
}

/// Reconnect the tunnel for `key` in place — same loopback port and token —
/// after the app has confirmed (two failed liveness probes) that a tunnel
/// reporting connected is dead. Non-blocking; no-op when it isn't running.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_force_reconnect(key: *const c_char) {
    if let Some(key) = string_arg(key, "key") {
        guard((), || tunnel_force_reconnect(&key));
    }
}

/// Swap the credential the tunnel for `key` dials with (a refreshed guest
/// ticket, or a new pairing code for the same server), in place — same port,
/// same token. Returns 0 on success, -1 on error (then call
/// [`mstream_iroh_last_error`]): no such tunnel, an unparseable code, or a
/// code for a different server or kind. Non-blocking.
///
/// # Safety
/// `key` and `code` must be valid NUL-terminated C strings for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_set_credential(key: *const c_char, code: *const c_char) -> i32 {
    let (Some(key), Some(code)) = (string_arg(key, "key"), string_arg(code, "code")) else {
        return -1;
    };
    guard(-1, move || match tunnel_set_credential(&key, &code) {
        Ok(()) => 0,
        Err(e) => {
            set_last_error(e);
            -1
        }
    })
}

/// Native events for the tunnel for `key` since the last call as a heap
/// NUL-terminated C string (one event per line) the caller must free with
/// [`mstream_iroh_string_free`], or null when there is nothing new. The app
/// appends them to its diagnostics log.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_drain_events(key: *const c_char) -> *mut c_char {
    match string_arg(key, "key") {
        Some(key) => guard(std::ptr::null_mut(), || string_out(tunnel_drain_events(&key))),
        None => std::ptr::null_mut(),
    }
}

/// Whether the tunnel for `key` has a home relay connected: 1 yes, 0 no, -1
/// unknown (no such tunnel).
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_relay_online(key: *const c_char) -> i32 {
    match string_arg(key, "key") {
        Some(key) => guard(-1, || tunnel_relay_online(&key)),
        None => -1,
    }
}

/// The loopback auth token of the tunnel for `key` as a heap NUL-terminated C
/// string the caller must free with [`mstream_iroh_string_free`], or null if
/// it isn't running. The app appends it to loopback URLs as `__lt=<token>`.
///
/// # Safety
/// `key` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_local_token(key: *const c_char) -> *mut c_char {
    match string_arg(key, "key") {
        Some(key) => guard(std::ptr::null_mut(), || string_out(tunnel_local_token(&key))),
        None => std::ptr::null_mut(),
    }
}

/// The last error message as a heap-allocated NUL-terminated C string, or null if
/// none. The caller OWNS the returned pointer and must free it with
/// [`mstream_iroh_string_free`].
#[no_mangle]
pub extern "C" fn mstream_iroh_last_error() -> *mut c_char {
    // Poison-tolerant (no unwrap panic across the C ABI): recover the inner value
    // if a writer ever panicked while holding the lock.
    match LAST_ERROR.lock().unwrap_or_else(|e| e.into_inner()).as_ref() {
        Some(s) => s.clone().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Free a string returned by any `mstream_iroh_*` function that hands out a
/// heap C string.
///
/// # Safety
/// `p` must be a pointer previously returned by this library (or null).
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_string_free(p: *mut c_char) {
    if !p.is_null() {
        let _ = CString::from_raw(p);
    }
}

// Mirror panics/errors to logcat (`adb logcat -s iroh_tunnel`) on Android.
fn log_android(msg: &str) {
    crate::platform_log(crate::PLATFORM_LOG_ERROR, msg);
}
