//! iOS < 18 launch-crash shim for `nw_path_is_ultra_constrained`.
//!
//! The `netdev` crate (a transitive dep via iroh's network monitoring) calls
//! Network.framework's `nw_path_is_ultra_constrained` through a plain
//! `extern "C"` block — a STRONG dyld reference to a symbol that only exists
//! on iOS 18+. On iOS 15–17 dyld aborts the entire app at launch:
//!
//!   Symbol not found: (_nw_path_is_ultra_constrained)
//!   Referenced from: iroh_tunnel.framework/iroh_tunnel
//!   Expected in: /System/Library/Frameworks/Network.framework/Network
//!
//! (Found via an iPhone X / iOS 15.6 crash log; every simulator run passed
//! because current simulators ARE iOS 18+.)
//!
//! Defining the symbol HERE makes the static linker resolve netdev's
//! reference inside this dylib, so the external Network.framework import
//! never exists. At runtime we forward to the real implementation when the OS
//! has it and report "not ultra-constrained" otherwise — the only cost on old
//! iOS is netdev missing a power-saving hint that those versions can't
//! express anyway.
//!
//! Remove once netdev gates the call itself (0.45 still doesn't).

#![cfg(target_os = "ios")]

use std::ffi::{c_char, c_int, c_void};
use std::sync::OnceLock;

extern "C" {
    fn dlopen(path: *const c_char, mode: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
}

const RTLD_LAZY: c_int = 0x1;

type UltraConstrainedFn = unsafe extern "C" fn(*mut c_void) -> bool;

fn real_impl() -> Option<UltraConstrainedFn> {
    static REAL: OnceLock<Option<UltraConstrainedFn>> = OnceLock::new();
    *REAL.get_or_init(|| unsafe {
        // dlsym on the framework's own handle, NOT RTLD_DEFAULT — a global
        // lookup would find this very stub and recurse. Network.framework is
        // already loaded (netdev binds other, older symbols from it), so this
        // dlopen just bumps a refcount.
        let handle = dlopen(
            c"/System/Library/Frameworks/Network.framework/Network".as_ptr(),
            RTLD_LAZY,
        );
        if handle.is_null() {
            return None;
        }
        let sym = dlsym(handle, c"nw_path_is_ultra_constrained".as_ptr());
        if sym.is_null() {
            None // iOS < 18
        } else {
            Some(std::mem::transmute::<*mut c_void, UltraConstrainedFn>(sym))
        }
    })
}

/// # Safety
/// `path` must be a valid `nw_path_t`, exactly as the real API requires; this
/// shim passes it straight through (and never dereferences it itself).
#[no_mangle]
pub unsafe extern "C" fn nw_path_is_ultra_constrained(path: *mut c_void) -> bool {
    match real_impl() {
        Some(real) => real(path),
        None => false,
    }
}
