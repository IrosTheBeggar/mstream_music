package com.example.mstream_music

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

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
    }
}
