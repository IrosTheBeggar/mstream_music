//! C ABI for Dart FFI (`dart:ffi`).
//!
//! The tunnel's surface is tiny (start / stop / is-active / last-error), so a
//! hand-written C ABI consumed via `dart:ffi` is simpler and lighter than a
//! flutter_rust_bridge codegen step — no generator in the build, just one `.so`
//! and a small Dart wrapper.
//!
//! ABI v2: tunnels are keyed by pairing code, so every per-tunnel entry point
//! takes the code as its first argument and distinct codes can run concurrently.
//! The symbol NAMES are unchanged from v1 on purpose: against a stale v1 binary
//! (the committed iOS framework until build-ios.sh is re-run on a Mac) the extra
//! argument lands in an unused register and the old single-tunnel semantics
//! apply — exactly right while the app drives one tunnel at a time. The Dart
//! side detects v1 via the absent [`mstream_iroh_abi_version`] symbol and keeps
//! its one-iroh-server behavior there.
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
    tunnel_is_active, tunnel_local_token, tunnel_network_changed, tunnel_path_kind, tunnel_start,
    tunnel_status, tunnel_stop,
};

/// Bumped whenever the C ABI changes shape. v2 = pairing-code-keyed tunnels.
/// The symbol itself is the version probe: v1 binaries don't export it.
const ABI_VERSION: i32 = 2;

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

// Borrow a NUL-terminated UTF-8 pairing code; None on null / invalid UTF-8.
//
// # Safety
// `p` must be null or a valid NUL-terminated C string for the duration of use.
unsafe fn code_arg<'a>(p: *const c_char) -> Option<&'a str> {
    if p.is_null() {
        return None;
    }
    CStr::from_ptr(p).to_str().ok()
}

/// The C ABI version (see [`ABI_VERSION`]). New in v2 — probe for this symbol to
/// distinguish a v1 binary (absent → single-tunnel, key arguments ignored).
#[no_mangle]
pub extern "C" fn mstream_iroh_abi_version() -> i32 {
    ABI_VERSION
}

/// Start the tunnel for a NUL-terminated UTF-8 composite pairing code.
/// Returns the loopback port (> 0) on success, or -1 on error — then call
/// [`mstream_iroh_last_error`]. Idempotent per code (returns the existing port
/// if that code's tunnel is running).
///
/// # Safety
/// `pairing_code` must be a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_start(pairing_code: *const c_char, local_port: u16) -> i32 {
    let code = match code_arg(pairing_code) {
        Some(s) => s.to_owned(),
        None => {
            set_last_error("pairing_code is null or not valid UTF-8".into());
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

/// Stop `pairing_code`'s tunnel (graceful). Safe to call when it isn't running.
///
/// # Safety
/// `pairing_code` must be null or a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_stop(pairing_code: *const c_char) {
    let code = code_arg(pairing_code);
    guard((), || {
        if let Some(c) = code {
            tunnel_stop(c);
        }
    });
}

/// Whether `pairing_code`'s tunnel is currently CONNECTED.
///
/// # Safety
/// `pairing_code` must be null or a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_is_active(pairing_code: *const c_char) -> bool {
    let code = code_arg(pairing_code);
    guard(false, || code.is_some_and(tunnel_is_active))
}

/// `pairing_code`'s tunnel status: one of the STATUS_* codes (0=connecting,
/// 1=connected, 2=reconnecting, 3=rejected/re-pair, 4=down). Mirrors lib.rs
/// STATUS_* and the Dart `IrohTunnelStatus` enum.
///
/// # Safety
/// `pairing_code` must be null or a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_status(pairing_code: *const c_char) -> i32 {
    let code = code_arg(pairing_code);
    guard(crate::STATUS_DOWN as i32, || {
        code.map_or(crate::STATUS_DOWN as i32, |c| tunnel_status(c) as i32)
    })
}

/// Tell every running tunnel the device network changed (call on connectivity
/// transitions — iroh can't self-detect them on Android).
#[no_mangle]
pub extern "C" fn mstream_iroh_network_changed() {
    guard((), tunnel_network_changed);
}

/// `pairing_code`'s tunnel path kind: 0=unknown, 1=direct (hole-punched),
/// 2=relayed. Mirrors the PATH_* constants in lib.rs and the Dart `IrohPathKind`
/// enum.
///
/// # Safety
/// `pairing_code` must be null or a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_path_kind(pairing_code: *const c_char) -> i32 {
    let code = code_arg(pairing_code);
    guard(crate::PATH_UNKNOWN as i32, || {
        code.map_or(crate::PATH_UNKNOWN as i32, |c| tunnel_path_kind(c) as i32)
    })
}

/// `pairing_code`'s tunnel loopback auth token as a heap NUL-terminated C string
/// the caller must free with [`mstream_iroh_string_free`], or null if that tunnel
/// isn't running. The app appends it to loopback URLs as `__lt=<token>`.
///
/// # Safety
/// `pairing_code` must be null or a valid NUL-terminated C string for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn mstream_iroh_local_token(pairing_code: *const c_char) -> *mut c_char {
    let code = code_arg(pairing_code);
    guard(std::ptr::null_mut(), || {
        match code.and_then(tunnel_local_token) {
            Some(t) => CString::new(t)
                .map(|c| c.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            None => std::ptr::null_mut(),
        }
    })
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
