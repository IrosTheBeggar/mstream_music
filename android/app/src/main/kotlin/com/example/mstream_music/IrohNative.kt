package com.example.mstream_music

import android.content.Context

// Loads libiroh_tunnel.so via the JVM (so its JNI symbols resolve) and hands the
// app Context to the native side. iroh's network monitoring reaches Android's
// ConnectivityManager through ndk_context, which must be initialized with the
// Context before any tunnel call — otherwise the first call panics with
// "android context was not initialized". The Dart side (lib/native/iroh_tunnel.dart)
// then uses the same already-loaded library via dart:ffi.
object IrohNative {
    @Volatile private var initialized = false

    init {
        System.loadLibrary("iroh_tunnel")
    }

    private external fun nativeInit(context: Context)

    fun ensureInit(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (!initialized) {
                nativeInit(context.applicationContext)
                initialized = true
            }
        }
    }
}
