// Dart client for the Kotlin VisualizerBridge plugin. Owns no state of
// its own beyond the current texture id — the real lifetime lives in
// the Kotlin render thread.

import 'dart:typed_data';

import 'package:flutter/services.dart';

class VisualizerBridge {
  static const _channel = MethodChannel('mstream/visualizer');

  /// Engine identifiers — matches the enum in native/visualizer_bridge.cpp.
  static const int engineProjectM = 0;
  static const int engineShader = 1;

  /// Asks Kotlin to allocate a SurfaceTexture + EGL context + visualizer
  /// engine at [width] × [height]. [engine] picks which renderer:
  /// `engineProjectM` (default, Milkdrop) or `engineShader` (Shadertoy
  /// fragment shaders). Returns the Flutter texture id (to hand to a
  /// [Texture] widget) on success, or `null` on failure.
  static Future<int?> create({
    required int width,
    required int height,
    int engine = engineProjectM,
  }) async {
    try {
      final id = await _channel.invokeMethod<int>('create', {
        'width': width,
        'height': height,
        'engine': engine,
      });
      return id;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('VisualizerBridge.create failed: ${e.code} ${e.message}');
      return null;
    }
  }

  /// Pushes a chunk of interleaved stereo Float32 PCM samples into the
  /// render thread's queue. The data is consumed on the next frame.
  /// Safe to call from any isolate at any rate; the bridge caps its
  /// backlog so we don't OOM if the render thread stalls.
  static Future<void> addPcm(Float32List samples) async {
    try {
      await _channel.invokeMethod('addPcm', {'samples': samples});
    } on PlatformException {
      // best-effort: visualizer audio is cosmetic
    }
  }

  /// Loads a Milkdrop preset from in-memory `.milk` text. Faster than
  /// the file-path variant since native code doesn't have to read from
  /// the filesystem (or be granted permission to). [smooth] enables
  /// the soft-cut transition animation between presets.
  static Future<void> loadPreset(String data, {bool smooth = true}) async {
    try {
      await _channel.invokeMethod('loadPreset', {
        'data': data,
        'smooth': smooth,
      });
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('VisualizerBridge.loadPreset failed: ${e.code} ${e.message}');
    }
  }

  /// Parks the native render thread until [resume] is called. Use
  /// when the app moves to the background (`AppLifecycleState.paused`
  /// or `.inactive`) so the visualizer doesn't burn CPU/GPU off-screen.
  /// The EGL context + projectM handle stay alive; only the render
  /// loop suspends.
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException {
      // ignore
    }
  }

  /// Wakes the render thread parked by [pause].
  static Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
    } on PlatformException {
      // ignore
    }
  }

  /// Tears down the render thread, EGL context, and projectM handle.
  /// Call from VisualizerScreen.dispose().
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } on PlatformException {
      // ignore
    }
  }
}

