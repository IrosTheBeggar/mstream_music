//! Android-only: register the JavaVM + application Context with `ndk_context`.
//!
//! iroh's network monitoring reaches Android's ConnectivityManager through
//! `ndk_context::android_context()`. When the `.so` is loaded via `dart:ffi`
//! (`dlopen`), `JNI_OnLoad` never runs and that context is never set, so the
//! first iroh call panics with "android context was not initialized".
//!
//! Kotlin's `IrohNative` loads this lib via `System.loadLibrary` (so this JNI
//! symbol resolves) and calls `nativeInit(applicationContext)` once at startup.

use std::ffi::c_void;

use jni::objects::JObject;
use jni::JNIEnv;

/// JNI: `com.example.mstream_music.IrohNative.nativeInit(Context)`.
#[no_mangle]
pub extern "system" fn Java_com_example_mstream_1music_IrohNative_nativeInit<'local>(
    env: JNIEnv<'local>,
    _this: JObject<'local>,
    context: JObject<'local>,
) {
    let vm = match env.get_java_vm() {
        Ok(vm) => vm,
        Err(_) => return,
    };
    // A global ref so the Context survives past this call; intentionally leaked
    // (forget) to keep it valid for the whole process lifetime.
    let ctx = match env.new_global_ref(&context) {
        Ok(g) => g,
        Err(_) => return,
    };
    unsafe {
        ndk_context::initialize_android_context(
            vm.get_java_vm_pointer() as *mut c_void,
            ctx.as_obj().as_raw() as *mut c_void,
        );
    }
    std::mem::forget(ctx);
}
