package com.example.mstream_music

import android.app.Application

// Process-wide native init. Runs on EVERY process start — including the
// HEADLESS service binds (media-resumption chip, Bluetooth media key, Android
// Auto) where MainActivity never exists. IrohNative used to be initialized
// only from MainActivity.configureFlutterEngine, so a headless boot had no
// working tunnel: ndk_context panicked ("android context was not
// initialized"), every iroh stream URL failed, and a saved iroh queue could
// not resume. MainActivity keeps its own (idempotent) call as a belt.
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Guarded so a missing/unloadable .so never blocks boot — the feature
        // just stays unavailable (mirrors MainActivity).
        try {
            IrohNative.ensureInit(this)
        } catch (e: Throwable) {
            android.util.Log.w("IrohNative", "iroh native init failed: ${e.message}")
        }
    }
}
