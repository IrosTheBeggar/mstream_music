//! C ABI for Dart FFI (`dart:ffi`).
//!
//! The tunnel's surface is tiny (start / stop / is-active / last-error), so a
//! hand-written C ABI consumed via `dart:ffi` is simpler and lighter than a
//! flutter_rust_bridge codegen step — no generator in the build, just one `.so`
//! and a small Dart wrapper.
//!
//! Every entry point is **panic-guarded**: a panic in the tunnel/iroh code is
//! captured (message + location) into the last-error slot and returned as an
//! error, instead of unwinding across the `extern "C"` boundary and aborting the
//! whole app. On Android the message is also written to logcat (tag
//! `iroh_tunnel`).
//!
//! Threading: `mstream_iroh_start` blocks (relay warmup + dial, up to ~30s), so
//! Dart must call it off the UI isolate (e.g. `Isolate.run`).

use std::ffi::{c_char, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::sync::{Mutex, OnceLock};

use crate::ffi::{
    tunnel_is_active, tunnel_network_changed, tunnel_path_kind, tunnel_start, tunnel_status,
    tunnel_stop,
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

/// Start the tunnel from a NUL-terminated UTF-8 composite pairing code.
/// Returns the loopback port (> 0) on success, or -1 on error — then call
/// [`mstream_iroh_last_error`]. Idempotent (returns the existing port if running).
///
/// # Safety
/// `pairing_code` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_start(pairing_code: *const c_char, local_port: u16) -> i32 {
    if pairing_code.is_null() {
        set_last_error("pairing_code is null".into());
        return -1;
    }
    let code = match CStr::from_ptr(pairing_code).to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => {
            set_last_error("pairing_code is not valid UTF-8".into());
            return -1;
        }
    };
    guard(-1, move || match tunnel_start(code, local_port) {
        Ok(port) => port as i32,
        Err(e) => {
            set_last_error(e);
            -1
        }
    })
}

/// Stop the tunnel (graceful). Safe to call when nothing is running.
#[no_mangle]
pub extern "C" fn mstream_iroh_stop() {
    guard((), tunnel_stop);
}

/// Whether the tunnel is currently CONNECTED.
#[no_mangle]
pub extern "C" fn mstream_iroh_is_active() -> bool {
    guard(false, tunnel_is_active)
}

/// Current status: one of the STATUS_* codes (0=connecting, 1=connected,
/// 2=reconnecting, 3=rejected/re-pair, 4=down). Mirrors lib.rs STATUS_* and the
/// Dart `IrohTunnelStatus` enum.
#[no_mangle]
pub extern "C" fn mstream_iroh_status() -> i32 {
    guard(crate::STATUS_DOWN as i32, || tunnel_status() as i32)
}

/// Tell the tunnel the device network changed (call on connectivity transitions
/// — iroh can't self-detect them on Android).
#[no_mangle]
pub extern "C" fn mstream_iroh_network_changed() {
    guard((), tunnel_network_changed);
}

/// Current path kind: 0=unknown, 1=direct (hole-punched), 2=relayed. Mirrors the
/// PATH_* constants in lib.rs and the Dart `IrohPathKind` enum.
#[no_mangle]
pub extern "C" fn mstream_iroh_path_kind() -> i32 {
    guard(crate::PATH_UNKNOWN as i32, || tunnel_path_kind() as i32)
}

/// The last error message as a heap-allocated NUL-terminated C string, or null if
/// none. The caller OWNS the returned pointer and must free it with
/// [`mstream_iroh_string_free`].
#[no_mangle]
pub extern "C" fn mstream_iroh_last_error() -> *mut c_char {
    match LAST_ERROR.lock().unwrap().as_ref() {
        Some(s) => s.clone().into_raw(),
        None => std::ptr::null_mut(),
    }
}

/// Free a string returned by [`mstream_iroh_last_error`].
///
/// # Safety
/// `p` must be a pointer previously returned by [`mstream_iroh_last_error`] (or null).
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_string_free(p: *mut c_char) {
    if !p.is_null() {
        let _ = CString::from_raw(p);
    }
}

// Mirror panics/errors to logcat (`adb logcat -s iroh_tunnel`) on Android.
#[cfg(target_os = "android")]
fn log_android(msg: &str) {
    #[link(name = "log")]
    extern "C" {
        fn __android_log_write(prio: i32, tag: *const c_char, text: *const c_char) -> i32;
    }
    if let (Ok(tag), Ok(text)) = (CString::new("iroh_tunnel"), CString::new(msg)) {
        // 6 == ANDROID_LOG_ERROR
        unsafe { __android_log_write(6, tag.as_ptr(), text.as_ptr()) };
    }
}
#[cfg(not(target_os = "android"))]
fn log_android(_msg: &str) {}
