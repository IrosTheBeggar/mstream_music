// Dart client for the Kotlin VisualizerBridge plugin. Owns no state of
// its own beyond the current texture id — the real lifetime lives in
// the Kotlin render thread.

import 'dart:typed_data';

import 'package:flutter/services.dart';

class VisualizerBridge {
  static const _channel = MethodChannel('mstream/visualizer');

  /// Asks Kotlin to allocate a SurfaceTexture + EGL context + projectM
  /// handle at [width] × [height]. Returns the Flutter texture id (to
  /// hand to a [Texture] widget) on success, or `null` on failure.
  static Future<int?> create({required int width, required int height}) async {
    try {
      final id = await _channel.invokeMethod<int>('create', {
        'width': width,
        'height': height,
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
