// Dart FFI binding for the visualizer audio sidecar (rust/viz_decoder).
//
// Talks to the C ABI in `rust/viz_decoder/src/c_api.rs` via the prebuilt
// `viz_decoder.framework` embedded in the app bundle (vended by
// packages/viz_decoder_native, built by rust/viz_decoder/build-ios.sh).
//
// The sidecar decodes the CURRENTLY-PLAYING source — a downloaded file or the
// same stream URL the player uses — and [read] serves the mono PCM window
// ending at a playback position, which SpectrumSource FFTs into the shader
// visualizer's audio texture. Everything is guarded the same way as
// audio_capture.dart: an unsupported platform, a failed start, an unsupported
// codec (e.g. an opus transcode) or an unreachable source all degrade to "no
// samples" and callers fall back to the synthesized signal, never crash.
//
// `start` only spawns the native decode thread and `read` never blocks, so
// both are safe on the UI isolate at frame rate.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _StartNative = Int32 Function(Pointer<Utf8>);
typedef _StartDart = int Function(Pointer<Utf8>);
typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();
typedef _BoolNative = Bool Function();
typedef _BoolDart = bool Function();
typedef _Int32Native = Int32 Function();
typedef _Int32Dart = int Function();
typedef _ReadNative = Int32 Function(Uint64, Pointer<Float>, Int32);
typedef _ReadDart = int Function(int, Pointer<Float>, int);
typedef _LastErrNative = Pointer<Utf8> Function();
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

class VizDecoder {
  VizDecoder._();
  static final VizDecoder instance = VizDecoder._();

  DynamicLibrary? _lib;
  late final _StartDart _start;
  late final _VoidDart _stop;
  late final _ReadDart _read;
  late final _Int32Dart _sampleRate;
  late final _BoolDart _isActive;
  late final _LastErrNative _lastError;
  late final _FreeDart _stringFree;

  bool _running = false;
  Pointer<Float>? _buf;
  int _bufLen = 0;

  /// Platforms whose build bundles the sidecar framework: iOS
  /// (viz_decoder_native/ios, build-ios.sh) and macOS
  /// (viz_decoder_native/macos, build-macos.sh) — macOS has no WASAPI-style
  /// loopback capture, so re-decoding the playing track is its real-audio
  /// path. Windows keeps the WASAPI shim instead.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  /// True after a successful [start] until [stop]. The native session may
  /// still be priming or dead (bad source) — [read] reports that per call.
  bool get isRunning => _running;

  /// Decoded sample rate, 0 until the native probe finishes.
  int get sampleRate => (_lib == null || !_running) ? 0 : _sampleRate();

  /// The framework is linked at launch on both platforms (SPM links the
  /// binaryTarget product into Runner), so the process image already has the
  /// symbols — try that first, then the explicit framework paths (iOS's
  /// shallow layout, then macOS's versioned one) as fallbacks.
  static DynamicLibrary _resolveLib() {
    final process = DynamicLibrary.process();
    if (process.providesSymbol('mstream_vizdec_start')) return process;
    try {
      return DynamicLibrary.open('viz_decoder.framework/viz_decoder');
    } catch (_) {
      return DynamicLibrary.open(
          'viz_decoder.framework/Versions/A/viz_decoder');
    }
  }

  bool _open() {
    if (_lib != null) return true;
    if (!isSupported) return false;
    try {
      final lib = _resolveLib();
      _start = lib.lookupFunction<_StartNative, _StartDart>('mstream_vizdec_start');
      _stop = lib.lookupFunction<_VoidNative, _VoidDart>('mstream_vizdec_stop');
      _read = lib.lookupFunction<_ReadNative, _ReadDart>('mstream_vizdec_read');
      _sampleRate =
          lib.lookupFunction<_Int32Native, _Int32Dart>('mstream_vizdec_sample_rate');
      _isActive =
          lib.lookupFunction<_BoolNative, _BoolDart>('mstream_vizdec_is_active');
      _lastError = lib
          .lookup<NativeFunction<_LastErrNative>>('mstream_vizdec_last_error')
          .asFunction();
      _stringFree = lib.lookupFunction<_FreeNative, _FreeDart>(
          'mstream_vizdec_string_free');
      _lib = lib;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Begin decoding [source] (http(s):// URL, file:// URL, or a filesystem
  /// path), replacing any previous session — a track change is just another
  /// start. Returns false when unsupported/failed; [lastError] explains.
  bool start(String source) {
    if (!_open()) return false;
    final p = source.toNativeUtf8();
    try {
      if (_start(p) != 0) return false;
    } finally {
      calloc.free(p);
    }
    _running = true;
    return true;
  }

  void stop() {
    if (!_running) return;
    _stop();
    _running = false;
  }

  /// Copy the mono window ENDING at playback position [positionMs] into [out]
  /// (first [count] slots). Returns the samples written: [count] when the
  /// window was served, 0 while it isn't buffered (callers treat a short read
  /// as "not ready" and fall back to synth), and 0 with the session marked
  /// not-running once the native side reports the source dead.
  int read(Float32List out, int count, int positionMs) {
    if (!_running || count <= 0 || positionMs < 0) return 0;
    if (_buf == null || _bufLen < count) {
      if (_buf != null) calloc.free(_buf!);
      _buf = calloc<Float>(count);
      _bufLen = count;
    }
    final n = _read(positionMs, _buf!, count);
    if (n < 0) {
      // Session died (unsupported codec, unreachable source): stop asking so
      // every frame doesn't cross the FFI for a known-dead source. The screen
      // may start() a fresh session on the next track.
      _running = false;
      return 0;
    }
    final p = _buf!;
    for (var i = 0; i < n; i++) {
      out[i] = p[i];
    }
    return n;
  }

  /// Whether the native session exists and hasn't failed.
  bool get isActive => _lib != null && _running && _isActive();

  String lastError() {
    if (_lib == null) return 'viz_decoder framework not loaded';
    final p = _lastError();
    if (p == nullptr) return '';
    final s = p.toDartString();
    _stringFree(p);
    return s;
  }

  void dispose() {
    stop();
    if (_buf != null) {
      calloc.free(_buf!);
      _buf = null;
      _bufLen = 0;
    }
  }
}
