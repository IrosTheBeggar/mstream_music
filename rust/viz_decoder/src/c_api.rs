//! C ABI for Dart FFI (`dart:ffi`), following rust/iroh_tunnel/src/c_api.rs:
//! a tiny hand-written surface, every entry point panic-guarded so nothing
//! unwinds across the `extern "C"` boundary — a panic lands in the last-error
//! slot and the call reports failure, and the Dart side falls back to the
//! synthesized visualizer signal.
//!
//! Threading: `mstream_vizdec_start` only spawns the decode thread and
//! `mstream_vizdec_read` never blocks, so everything is safe to call from the
//! UI isolate at frame rate.

use std::ffi::{c_char, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::sync::{Mutex, OnceLock};

use crate::engine::{
    global_is_active, global_read, global_sample_rate, global_start, global_stop, last_error,
    set_last_error,
};

static LAST_PANIC: Mutex<Option<String>> = Mutex::new(None);
static PANIC_HOOK: OnceLock<()> = OnceLock::new();

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
            *LAST_PANIC.lock().unwrap_or_else(|e| e.into_inner()) =
                Some(format!("panic at {loc}: {msg}"));
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
                .unwrap_or_else(|e| e.into_inner())
                .take()
                .unwrap_or_else(|| "panic in viz decoder".into());
            set_last_error(msg);
            default
        }
    }
}

/// Start decoding `source` (NUL-terminated UTF-8: http(s):// URL, file:// URL,
/// or a filesystem path), replacing any active session. Returns 0 on success,
/// -1 on error (then call [`mstream_vizdec_last_error`]). Never blocks — open
/// and probe failures surface later as a dead session (`read` → -1).
///
/// # Safety
/// `source` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_vizdec_start(source: *const c_char) -> i32 {
    if source.is_null() {
        set_last_error("source is null".into());
        return -1;
    }
    let url = match CStr::from_ptr(source).to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => {
            set_last_error("source is not valid UTF-8".into());
            return -1;
        }
    };
    guard(-1, move || match global_start(&url) {
        Ok(()) => 0,
        Err(e) => {
            set_last_error(e);
            -1
        }
    })
}

/// Stop the active session. Safe to call when nothing is running.
#[no_mangle]
pub extern "C" fn mstream_vizdec_stop() {
    guard((), global_stop);
}

/// Copy the mono f32 window ENDING at `position_ms` into `out` (capacity
/// `count`). Returns `count` when the full window was served, 0 while it isn't
/// buffered yet (the caller should fall back to its synthesized signal for the
/// frame), and -1 once the session is dead or absent. Non-blocking; also
/// retargets the decode thread at `position_ms`.
///
/// # Safety
/// `out` must point to at least `count` writable f32 slots.
#[no_mangle]
pub unsafe extern "C" fn mstream_vizdec_read(position_ms: u64, out: *mut f32, count: i32) -> i32 {
    if out.is_null() || count <= 0 {
        return -1;
    }
    let slice = std::slice::from_raw_parts_mut(out, count as usize);
    guard(-1, move || global_read(position_ms, slice))
}

/// Decoded sample rate of the active session, or 0 until the probe finished
/// (and when no session is active).
#[no_mangle]
pub extern "C" fn mstream_vizdec_sample_rate() -> i32 {
    guard(0, || global_sample_rate() as i32)
}

/// True while a session exists and hasn't failed.
#[no_mangle]
pub extern "C" fn mstream_vizdec_is_active() -> bool {
    guard(false, global_is_active)
}

/// The last error message as a heap-allocated NUL-terminated C string, or null
/// if none. The caller OWNS the returned pointer and must free it with
/// [`mstream_vizdec_string_free`].
#[no_mangle]
pub extern "C" fn mstream_vizdec_last_error() -> *mut c_char {
    guard(std::ptr::null_mut(), || match last_error() {
        Some(s) => CString::new(s)
            .map(|c| c.into_raw())
            .unwrap_or(std::ptr::null_mut()),
        None => std::ptr::null_mut(),
    })
}

/// Free a string returned by [`mstream_vizdec_last_error`].
///
/// # Safety
/// `p` must be a pointer previously returned by [`mstream_vizdec_last_error`]
/// (or null).
#[no_mangle]
pub unsafe extern "C" fn mstream_vizdec_string_free(p: *mut c_char) {
    if !p.is_null() {
        let _ = CString::from_raw(p);
    }
}
