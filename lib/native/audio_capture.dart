// Dart FFI binding for the WASAPI loopback capture shim (windows/audio_capture
// → audio_capture.dll). Provides the real playback signal for the desktop
// visualizer: the shim captures the default render endpoint into a mono ring
// buffer; [read] copies the most recent samples for the FFT (shaders) / addPcm
// (projectM) feed.
//
// Windows-only (WASAPI). Every entry point is guarded on the library having
// loaded and capture being active, so an unsupported platform or a failed start
// degrades to "no samples" (callers fall back to synthesized PCM) rather than
// crashing.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _IntVoidC = Int32 Function();
typedef _IntVoidD = int Function();
typedef _VoidC = Void Function();
typedef _VoidD = void Function();
typedef _ReadC = Int32 Function(Pointer<Float>, Int32);
typedef _ReadD = int Function(Pointer<Float>, int);
typedef _ErrC = Pointer<Utf8> Function();

class AudioCapture {
  AudioCapture._();
  static final AudioCapture instance = AudioCapture._();

  DynamicLibrary? _lib;
  late final _IntVoidD _start;
  late final _VoidD _stop;
  late final _ReadD _read;
  late final _IntVoidD _sampleRate;
  late final _ErrC _lastError;

  bool _running = false;
  Pointer<Float>? _buf;
  int _bufLen = 0;

  /// The capture shim only exists on Windows in this build.
  static bool get isSupported => Platform.isWindows;

  bool get isRunning => _running;
  int get sampleRate => _lib == null ? 0 : _sampleRate();

  bool _open() {
    if (_lib != null) return true;
    if (!isSupported) return false;
    try {
      final lib = DynamicLibrary.open('audio_capture.dll');
      _start = lib.lookupFunction<_IntVoidC, _IntVoidD>('ac_start');
      _stop = lib.lookupFunction<_VoidC, _VoidD>('ac_stop');
      _read = lib.lookupFunction<_ReadC, _ReadD>('ac_read');
      _sampleRate = lib.lookupFunction<_IntVoidC, _IntVoidD>('ac_sample_rate');
      _lastError = lib.lookupFunction<_ErrC, _ErrC>('ac_last_error');
      _lib = lib;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Begin loopback capture. Returns true once capture is running. Idempotent;
  /// on failure (no device / unsupported) it stays off and [lastError] explains.
  bool start() {
    if (_running) return true;
    if (!_open()) return false;
    if (_start() != 0) return false;
    _running = true;
    return true;
  }

  void stop() {
    if (!_running) return;
    _stop();
    _running = false;
  }

  /// Copy the most recent [count] mono samples (~[-1, 1]) into [out], oldest
  /// first. Returns the number actually written — less than [count] until the
  /// ring fills (callers treat a short read as "not ready" and fall back to
  /// synth). No-op (0) when capture isn't running.
  int read(Float32List out, int count) {
    if (!_running || count <= 0) return 0;
    if (_buf == null || _bufLen < count) {
      if (_buf != null) calloc.free(_buf!);
      _buf = calloc<Float>(count);
      _bufLen = count;
    }
    final n = _read(_buf!, count);
    final p = _buf!;
    for (var i = 0; i < n; i++) {
      out[i] = p[i];
    }
    return n;
  }

  String lastError() {
    if (_lib == null) return 'audio_capture.dll not loaded';
    final p = _lastError();
    return p == nullptr ? '' : p.toDartString();
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
