//! C ABI for Dart FFI (`dart:ffi`).
//!
//! The tunnel's surface is tiny (start / stop / is-active / last-error), so a
//! hand-written C ABI consumed via `dart:ffi` is simpler and lighter than a
//! flutter_rust_bridge codegen step — no generator in the build, just one `.so`
//! and a small Dart wrapper. (frb remains an option if a richer/async surface is
//! ever needed.) These `#[no_mangle]` exports are also what make the cdylib retain
//! the iroh code at link time.
//!
//! Threading: `mstream_iroh_start` blocks (relay warmup + dial, up to ~30s), so
//! Dart must call it off the UI isolate (e.g. `Isolate.run`). The accept loop then
//! runs on the tunnel's owned runtime; later calls return immediately.

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use crate::ffi::{tunnel_is_active, tunnel_start, tunnel_stop};

static LAST_ERROR: Mutex<Option<CString>> = Mutex::new(None);

fn set_last_error(msg: String) {
    *LAST_ERROR.lock().unwrap() = CString::new(msg).ok();
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
    match tunnel_start(code, local_port) {
        Ok(port) => port as i32,
        Err(e) => {
            set_last_error(e);
            -1
        }
    }
}

/// Stop the tunnel (graceful). Safe to call when nothing is running.
#[no_mangle]
pub extern "C" fn mstream_iroh_stop() {
    tunnel_stop();
}

/// Whether a tunnel is currently active.
#[no_mangle]
pub extern "C" fn mstream_iroh_is_active() -> bool {
    tunnel_is_active()
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
