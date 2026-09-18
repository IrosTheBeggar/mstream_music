// Raw FFI bindings for the libprojectM v4 C API.
//
// These mirror the function declarations in projectM-4/{core,audio,
// render_opengl,parameters}.h exactly. Higher-level Dart wrappers live
// in [projectm_controller.dart] — application code should use that
// class, not call into here directly.
//
// The library is loaded from the standard Android lookup path
// (jniLibs/<abi>/libprojectM.so). On other platforms the open() call
// throws and [ProjectMBindings.isAvailable] returns false.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Opaque struct representing a `projectm_handle` (i.e. `struct projectm*`).
final class ProjectMHandle extends Opaque {}

/// Mirrors `projectm_channels` in types.h (mono=1, stereo=2).
abstract final class ProjectMChannels {
  static const int mono = 1;
  static const int stereo = 2;
}

// ─────────────────────────────────────────────────────────────────────────
// Native function signatures (C side)
// ─────────────────────────────────────────────────────────────────────────

typedef _ProjectmCreateC = Pointer<ProjectMHandle> Function();
typedef _ProjectmDestroyC = Void Function(Pointer<ProjectMHandle>);
typedef _ProjectmRenderFrameC = Void Function(Pointer<ProjectMHandle>);
typedef _ProjectmSetWindowSizeC = Void Function(
    Pointer<ProjectMHandle>, Size, Size);
typedef _ProjectmPcmAddFloatC = Void Function(
    Pointer<ProjectMHandle>, Pointer<Float>, Uint32, Int32);
typedef _ProjectmLoadPresetFileC = Void Function(
    Pointer<ProjectMHandle>, Pointer<Utf8>, Bool);
typedef _ProjectmLoadPresetDataC = Void Function(
    Pointer<ProjectMHandle>, Pointer<Utf8>, Bool);
typedef _ProjectmSetPresetDurationC = Void Function(
    Pointer<ProjectMHandle>, Double);
typedef _ProjectmSetMeshSizeC = Void Function(
    Pointer<ProjectMHandle>, Size, Size);
typedef _ProjectmSetFpsC = Void Function(Pointer<ProjectMHandle>, Int32);
typedef _ProjectmResetTexturesC = Void Function(Pointer<ProjectMHandle>);
typedef _ProjectmGetVersionStringC = Pointer<Utf8> Function();

// ─────────────────────────────────────────────────────────────────────────
// Dart function signatures
// ─────────────────────────────────────────────────────────────────────────

typedef _ProjectmCreate = Pointer<ProjectMHandle> Function();
typedef _ProjectmDestroy = void Function(Pointer<ProjectMHandle>);
typedef _ProjectmRenderFrame = void Function(Pointer<ProjectMHandle>);
typedef _ProjectmSetWindowSize = void Function(
    Pointer<ProjectMHandle>, int, int);
typedef _ProjectmPcmAddFloat = void Function(
    Pointer<ProjectMHandle>, Pointer<Float>, int, int);
typedef _ProjectmLoadPresetFile = void Function(
    Pointer<ProjectMHandle>, Pointer<Utf8>, bool);
typedef _ProjectmLoadPresetData = void Function(
    Pointer<ProjectMHandle>, Pointer<Utf8>, bool);
typedef _ProjectmSetPresetDuration = void Function(
    Pointer<ProjectMHandle>, double);
typedef _ProjectmSetMeshSize = void Function(
    Pointer<ProjectMHandle>, int, int);
typedef _ProjectmSetFps = void Function(Pointer<ProjectMHandle>, int);
typedef _ProjectmResetTextures = void Function(Pointer<ProjectMHandle>);
typedef _ProjectmGetVersionString = Pointer<Utf8> Function();

// ─────────────────────────────────────────────────────────────────────────
// Bindings container
// ─────────────────────────────────────────────────────────────────────────

class ProjectMBindings {
  ProjectMBindings._(this._lib)
      : create = _lib
            .lookup<NativeFunction<_ProjectmCreateC>>('projectm_create')
            .asFunction<_ProjectmCreate>(),
        destroy = _lib
            .lookup<NativeFunction<_ProjectmDestroyC>>('projectm_destroy')
            .asFunction<_ProjectmDestroy>(),
        renderFrame = _lib
            .lookup<NativeFunction<_ProjectmRenderFrameC>>(
                'projectm_opengl_render_frame')
            .asFunction<_ProjectmRenderFrame>(),
        setWindowSize = _lib
            .lookup<NativeFunction<_ProjectmSetWindowSizeC>>(
                'projectm_set_window_size')
            .asFunction<_ProjectmSetWindowSize>(),
        pcmAddFloat = _lib
            .lookup<NativeFunction<_ProjectmPcmAddFloatC>>(
                'projectm_pcm_add_float')
            .asFunction<_ProjectmPcmAddFloat>(),
        loadPresetFile = _lib
            .lookup<NativeFunction<_ProjectmLoadPresetFileC>>(
                'projectm_load_preset_file')
            .asFunction<_ProjectmLoadPresetFile>(),
        loadPresetData = _lib
            .lookup<NativeFunction<_ProjectmLoadPresetDataC>>(
                'projectm_load_preset_data')
            .asFunction<_ProjectmLoadPresetData>(),
        setPresetDuration = _lib
            .lookup<NativeFunction<_ProjectmSetPresetDurationC>>(
                'projectm_set_preset_duration')
            .asFunction<_ProjectmSetPresetDuration>(),
        setMeshSize = _lib
            .lookup<NativeFunction<_ProjectmSetMeshSizeC>>(
                'projectm_set_mesh_size')
            .asFunction<_ProjectmSetMeshSize>(),
        setFps = _lib
            .lookup<NativeFunction<_ProjectmSetFpsC>>('projectm_set_fps')
            .asFunction<_ProjectmSetFps>(),
        resetTextures = _lib
            .lookup<NativeFunction<_ProjectmResetTexturesC>>(
                'projectm_reset_textures')
            .asFunction<_ProjectmResetTextures>(),
        getVersionString = _lib
            .lookup<NativeFunction<_ProjectmGetVersionStringC>>(
                'projectm_get_version_string')
            .asFunction<_ProjectmGetVersionString>();

  // Holds the loaded library open for the process lifetime.
  // ignore: unused_field
  final DynamicLibrary _lib;

  final _ProjectmCreate create;
  final _ProjectmDestroy destroy;
  final _ProjectmRenderFrame renderFrame;
  final _ProjectmSetWindowSize setWindowSize;
  final _ProjectmPcmAddFloat pcmAddFloat;
  final _ProjectmLoadPresetFile loadPresetFile;
  final _ProjectmLoadPresetData loadPresetData;
  final _ProjectmSetPresetDuration setPresetDuration;
  final _ProjectmSetMeshSize setMeshSize;
  final _ProjectmSetFps setFps;
  final _ProjectmResetTextures resetTextures;
  final _ProjectmGetVersionString getVersionString;

  /// Lazily-loaded singleton. Throws [ProjectMUnavailableException] if
  /// the shared library can't be opened (e.g. on iOS/macOS/Linux, or
  /// on an Android device where the .so wasn't bundled for the ABI).
  static ProjectMBindings? _instance;
  static String? _loadError;

  static ProjectMBindings get instance {
    if (_instance != null) return _instance!;
    if (_loadError != null) {
      throw ProjectMUnavailableException(_loadError!);
    }
    try {
      final lib = _open();
      _instance = ProjectMBindings._(lib);
      return _instance!;
    } catch (e) {
      _loadError = 'libprojectM failed to load: $e';
      throw ProjectMUnavailableException(_loadError!);
    }
  }

  /// True if [instance] would succeed. Safe to call without throwing.
  static bool get isAvailable {
    if (_instance != null) return true;
    if (_loadError != null) return false;
    try {
      instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static DynamicLibrary _open() {
    if (Platform.isAndroid) {
      // jniLibs/<abi>/libprojectM-4.so — Android's linker finds it
      // automatically. The -4 suffix comes from projectM's CMake
      // (matches libprojectM v4.x SONAME).
      return DynamicLibrary.open('libprojectM-4.so');
    }
    if (Platform.isWindows) {
      // Bundled next to the executable (windows/projectm/projectM-4.dll, built
      // from libprojectM v4.1.6 with MSVC). It imports glew32.dll, also bundled.
      // Loading + reading the version needs no GL context; the per-frame render
      // bridge (offscreen GL + FBO) is separate native work still to come.
      return DynamicLibrary.open('projectM-4.dll');
    }
    throw UnsupportedError(
        'libprojectM is only bundled for Android and Windows in this build');
  }
}

class ProjectMUnavailableException implements Exception {
  final String message;
  ProjectMUnavailableException(this.message);
  @override
  String toString() => 'ProjectMUnavailableException: $message';
}
