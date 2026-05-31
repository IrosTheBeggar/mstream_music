package com.example.mstream_music

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

        // Free-space query for the storage-migration pre-check (no pure-Dart
        // API for this). Returns available bytes on the volume holding `path`,
        // or null if it can't be read.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> {
                        val p = call.argument<String>("path")
                        try {
                            result.success(StatFs(p).availableBytes)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
