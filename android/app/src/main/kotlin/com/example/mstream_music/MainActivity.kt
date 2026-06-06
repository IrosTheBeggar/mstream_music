package com.example.mstream_music

import android.content.Intent
import android.os.Build
import android.os.StatFs
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
    }
}
