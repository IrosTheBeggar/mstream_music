// Manages user-supplied visualizer shaders kept in a folder on the
// device. The user drops Shadertoy-style `.glsl` files they've downloaded
// into this folder; [VisualizerPresets] merges them into the Shader-engine
// catalog and the native ShaderEngine compiles them at runtime — so they
// join the rotation without a rebuild/reinstall.
//
// We use the app-specific EXTERNAL files dir on Android
// (Android/data/<pkg>/files/shaders): it needs no runtime permission and
// is reachable over USB / a file manager so the user can put files in it.
// No file picker, no networking — deliberately minimal for this proof of
// concept. Shader (`.glsl`) only; Milkdrop `.milk` would slot in the same
// way later.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UserShaders {
  UserShaders._();
  static final UserShaders _instance = UserShaders._();
  factory UserShaders() => _instance;

  static const String _subdir = 'shaders';
  static const String _ext = '.glsl';

  Directory? _dirCache;

  /// The folder the user drops shaders into, created on first use.
  Future<Directory> _dir() async {
    final cached = _dirCache;
    if (cached != null) return cached;
    // App-specific external storage on Android (no permission needed,
    // user-reachable); private documents dir as a fallback elsewhere.
    final base = (Platform.isAndroid
            ? await getExternalStorageDirectory()
            : null) ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dirCache = dir;
    return dir;
  }

  /// Absolute path of the shader folder (created if needed). Shown in the
  /// UI so the user knows where to put files.
  Future<String> folderPath() async => (await _dir()).path;

  /// Absolute paths of every `.glsl` in the folder, sorted by file name.
  Future<List<String>> list() async {
    try {
      final dir = await _dir();
      final paths = <String>[
        await for (final e in dir.list())
          if (e is File && e.path.toLowerCase().endsWith(_ext)) e.path,
      ]..sort();
      return paths;
    } catch (_) {
      // A missing/unreadable folder just means nothing's there yet.
      return const [];
    }
  }

  /// Remove a shader file from the folder. No-op if it's already gone.
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  /// True if [path] is a user shader (absolute path) vs. a bundled asset
  /// (`assets/...` relative key).
  bool isImported(String path) => !path.startsWith('assets/');
}
