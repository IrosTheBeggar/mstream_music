// Idiomatic Dart wrapper over the raw projectM FFI bindings.
//
// Phase 1 scope is intentionally tiny: load the library, read the
// version. That's enough to verify the .so is bundled correctly and
// the symbol lookup works on a real device before we layer the EGL
// texture bridge and per-frame render loop on top.
//
// Creating an actual projectm_handle requires an active OpenGL ES
// context — that work belongs to the Kotlin texture bridge, not
// Dart. The handle-owning methods (createHandle, renderFrame, etc.)
// are stubs here; the bridge calls into projectM directly via JNI.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'projectm_bindings.dart';

class ProjectMController {
  /// True if libprojectM-4.so can be loaded and its symbols resolved
  /// on this device. False on iOS/macOS/Linux, false on Android if
  /// the .so wasn't bundled for the device's ABI.
  static bool get isAvailable => ProjectMBindings.isAvailable;

  /// projectM's compiled-in version string, e.g. "4.1.6".
  /// Throws [ProjectMUnavailableException] if the library isn't loaded.
  static String version() {
    final ptr = ProjectMBindings.instance.getVersionString();
    if (ptr == nullptr) return 'unknown';
    return ptr.toDartString();
  }

  /// Best-effort version read. Returns null instead of throwing.
  /// Useful for UI that wants to display whatever state we're in.
  static String? versionOrNull() {
    try {
      return version();
    } catch (_) {
      return null;
    }
  }

  /// Diagnostic string for the visualizer screen: "Loaded · v4.1.6"
  /// or "Not available — <reason>".
  static String statusLine() {
    if (!isAvailable) {
      return 'libprojectM not available on this device';
    }
    final v = versionOrNull();
    return v == null ? 'libprojectM loaded' : 'libprojectM loaded · v$v';
  }
}
