package com.example.mstream_music

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends AudioServiceActivity (from the audio_service pub package) so
// the media session / foreground notification plumbing still works,
// while giving us a place to register our in-app native plugins.
//
// The manifest must point at this class instead of
// com.ryanheise.audioservice.AudioServiceActivity directly.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the app Context with the iroh native lib (ndk_context) before
        // any tunnel call. Guarded so a missing/unloadable .so never blocks boot
        // (the feature just stays unavailable).
        try {
            IrohNative.ensureInit(this)
        } catch (e: Throwable) {
            android.util.Log.w("IrohNative", "iroh native init failed: ${e.message}")
        }

        flutterEngine.plugins.add(VisualizerBridge())

        // Flavor-specific: full installs the self-signed/insecure-TLS bridge for
        // ExoPlayer streaming; play provides a no-op (see src/<flavor>/kotlin).
        InsecureTls.register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Free bytes on the volume holding `path`, for the
                    // storage-migration pre-check (no pure-Dart API).
                    "freeBytes" -> {
                        val p = call.argument<String>("path")
                        try {
                            result.success(StatFs(p).availableBytes)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    // Start/stop a foreground service that keeps the process
                    // alive while a background file move runs (so it survives
                    // the app being backgrounded). Failures are non-fatal —
                    // the move proceeds regardless.
                    "startMove" -> {
                        try {
                            val i = Intent(this, MigrationService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(i)
                            } else {
                                startService(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stopMove" -> {
                        try {
                            stopService(Intent(this, MigrationService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Battery-optimization (Doze / OEM app-sleeping) exemption. A
        // foreground-service music player that isn't exempt can be frozen or
        // killed with the screen off → "playback stops". We CHECK the state and
        // open the system screen; we deliberately use the permission-free
        // settings-list intent, not the restricted one-tap request.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(
                                pm.isIgnoringBatteryOptimizations(packageName))
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
