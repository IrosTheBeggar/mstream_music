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

  /// Pushes live tuning values to the engine. Layout is
  /// `[minDb, maxDb, smoothing, p0, p1, …]`: the first three drive the
  /// native audio response curve, the rest fill the shaders' `iParams[]`
  /// uniform. Applied on the render thread before the next frame.
  /// No-op on the Milkdrop engine. Best-effort (purely cosmetic).
  static Future<void> setTuning(List<double> values) async {
    try {
      await _channel.invokeMethod(
          'setTuning', {'values': Float32List.fromList(values)});
    } on PlatformException {
      // best-effort: tuning is cosmetic
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

  /// Asks Kotlin to attach an `AndroidVisualizer` to the given audio
  /// session and stream waveform samples into the render thread's PCM
  /// queue. [sessionId] should be the app's own player session — the
  /// global mix (session 0) is blocked for normal apps on modern
  /// Android. Returns true on success, false if Visualizer creation
  /// failed (RECORD_AUDIO revoked, OS restriction, etc.); callers
  /// should fall back to synthesized PCM on false.
  static Future<bool> startRealAudio(int sessionId) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          'startRealAudio', {'sessionId': sessionId});
      return ok == true;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('VisualizerBridge.startRealAudio failed: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Stops the AndroidVisualizer if it's attached.
  static Future<void> stopRealAudio() async {
    try {
      await _channel.invokeMethod('stopRealAudio');
    } on PlatformException {
      // ignore
    }
  }

  /// Ask Kotlin to transcode [source] (a local file path or http URL) into a
  /// live MPEG-TS/HLS stream in the [output] directory — the app's visualizer
  /// reacting to the track, rendered with the in-memory [preset]/shader text.
  /// [maxMs] caps the transcoded duration (0 = whole track). Returns the
  /// playlist (`.m3u8`) path, available as soon as transcoding starts (segments
  /// keep being written in the background), or null on failure.
  static Future<String?> startTranscode({
    required String source,
    required String output,
    String? preset,
    int engine = engineProjectM,
    int width = 1280,
    int height = 720,
    int fps = 30,
    int maxMs = 0,
    List<double>? tuning,
  }) async {
    try {
      return await _channel.invokeMethod<String>('startTranscode', {
        'source': source,
        'output': output,
        'preset': preset,
        'engine': engine,
        'width': width,
        'height': height,
        'fps': fps,
        'maxMs': maxMs,
        'tuning': tuning != null ? Float32List.fromList(tuning) : null,
      });
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('VisualizerBridge.startTranscode failed: ${e.code} ${e.message}');
      return null;
    }
  }

  /// Cancels an in-progress [startTranscode].
  static Future<void> stopTranscode() async {
    try {
      await _channel.invokeMethod('stopTranscode');
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

