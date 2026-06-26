// Dart FFI binding for the desktop projectM render shim (windows/projectm_shim
// → projectm_desktop.dll). The shim owns an offscreen WGL OpenGL context + FBO and
// drives libprojectM; this wrapper feeds it PCM, asks for a rendered frame as
// RGBA bytes, and loads `.milk` preset text.
//
// Windows-only for now (the shim is WGL-based). Every entry point is guarded on
// [init] having succeeded, so a failed GL/context setup degrades to "no frames"
// instead of crashing.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _InitC = Int32 Function(Int32, Int32);
typedef _InitD = int Function(int, int);
typedef _AddPcmC = Void Function(Pointer<Float>, Int32);
typedef _AddPcmD = void Function(Pointer<Float>, int);
typedef _RenderC = Int32 Function(Pointer<Uint8>);
typedef _RenderD = int Function(Pointer<Uint8>);
typedef _LoadC = Void Function(Pointer<Utf8>, Int32);
typedef _LoadD = void Function(Pointer<Utf8>, int);
typedef _VoidC = Void Function();
typedef _VoidD = void Function();
typedef _ErrC = Pointer<Utf8> Function();

class ProjectMDesktop {
  ProjectMDesktop._();
  static final ProjectMDesktop instance = ProjectMDesktop._();

  DynamicLibrary? _lib;
  late final _InitD _init;
  late final _AddPcmD _addPcm;
  late final _RenderD _render;
  late final _LoadD _loadPreset;
  late final _VoidD _destroy;
  late final _ErrC _lastError;

  bool _initialized = false;
  int _w = 0, _h = 0;
  Pointer<Uint8>? _rgba; // readback buffer (w*h*4)
  Pointer<Float>? _pcm; // PCM scratch

  int get width => _w;
  int get height => _h;
  bool get isInitialized => _initialized;

  /// The shim only exists on Windows in this build.
  static bool get isSupported => Platform.isWindows;

  bool _open() {
    if (_lib != null) return true;
    if (!isSupported) return false;
    try {
      final lib = DynamicLibrary.open('projectm_desktop.dll');
      _init = lib.lookupFunction<_InitC, _InitD>('pmd_init');
      _addPcm = lib.lookupFunction<_AddPcmC, _AddPcmD>('pmd_add_pcm');
      _render = lib.lookupFunction<_RenderC, _RenderD>('pmd_render');
      _loadPreset =
          lib.lookupFunction<_LoadC, _LoadD>('pmd_load_preset_data');
      _destroy = lib.lookupFunction<_VoidC, _VoidD>('pmd_destroy');
      _lastError = lib.lookupFunction<_ErrC, _ErrC>('pmd_last_error');
      _lib = lib;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create the GL context + projectM at [w]×[h]. Returns true on success;
  /// [lastError] explains a failure.
  bool init(int w, int h) {
    if (_initialized) return true;
    if (!_open()) return false;
    if (_init(w, h) != 0) return false;
    _w = w;
    _h = h;
    _rgba = calloc<Uint8>(w * h * 4);
    _pcm = calloc<Float>(4096);
    _initialized = true;
    return true;
  }

  /// Feed up to 4096 mono PCM samples (range ~[-1, 1]).
  void addPcm(Float32List samples) {
    if (!_initialized) return;
    final n = samples.length > 4096 ? 4096 : samples.length;
    final p = _pcm!;
    for (var i = 0; i < n; i++) {
      p[i] = samples[i];
    }
    _addPcm(p, n);
  }

  /// Load a preset from in-memory `.milk` text.
  void loadPresetData(String milk, {bool smooth = true}) {
    if (!_initialized) return;
    final c = milk.toNativeUtf8();
    try {
      _loadPreset(c, smooth ? 1 : 0);
    } finally {
      malloc.free(c);
    }
  }

  /// Render one frame; returns a view of the RGBA bytes (w*h*4), in GL bottom-up
  /// row order (the caller flips for display). Null if not initialized / failed.
  /// The buffer is reused each call — copy or consume before the next render.
  Uint8List? renderFrame() {
    if (!_initialized) return null;
    if (_render(_rgba!) != 0) return null;
    return _rgba!.asTypedList(_w * _h * 4);
  }

  String lastError() {
    if (_lib == null) return 'projectm_desktop.dll not loaded';
    final p = _lastError();
    return p == nullptr ? '' : p.toDartString();
  }

  void dispose() {
    if (_initialized) {
      _destroy();
      _initialized = false;
    }
    if (_rgba != null) {
      calloc.free(_rgba!);
      _rgba = null;
    }
    if (_pcm != null) {
      calloc.free(_pcm!);
      _pcm = null;
    }
  }
}
