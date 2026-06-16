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

  /// The shader's `// title:` header (e.g. "Spectrum Bars"), or null if the
  /// file has none or can't be read — callers fall back to the file name.
  /// Only the top of the file is inspected; the header sits above the code.
  Future<String?> titleOf(String path) async {
    try {
      final lines = await File(path).readAsLines();
      for (final raw in lines.take(20)) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('//')) break; // header ends at the first code line
        final m = _titleRe.firstMatch(line);
        if (m != null) {
          final t = m.group(1)!.trim();
          if (t.isNotEmpty) return t;
        }
      }
    } catch (_) {
      // Unreadable file → no title; the caller shows the file name instead.
    }
    return null;
  }

  static final RegExp _titleRe =
      RegExp(r'^//\s*title:\s*(.+)$', caseSensitive: false);

  /// Cheap sanity check that [path] looks like a Shadertoy-style fragment
  /// shader: non-empty and exposes an entry point (`mainImage` or `main`).
  /// The native engine does the real GLSL compile — this just flags
  /// obviously-wrong files (empty / wrong type) in the UI first.
  Future<bool> looksValid(String path) async {
    try {
      final src = await File(path).readAsString();
      if (src.trim().isEmpty) return false;
      return src.contains('mainImage') || src.contains('void main');
    } catch (_) {
      return false;
    }
  }

  /// The device's public Downloads folder, derived from the app's external
  /// storage path (`…/Android/data/<pkg>/files` → the shared-storage root +
  /// `/Download`). Reading it on Android 11+ needs all-files access; null off
  /// Android or when the root can't be derived.
  Future<Directory?> downloadsDir() async {
    if (!Platform.isAndroid) return null;
    final ext = await getExternalStorageDirectory();
    if (ext == null) return null;
    final marker = '${p.separator}Android${p.separator}';
    final i = ext.path.indexOf(marker);
    final root = i >= 0 ? ext.path.substring(0, i) : ext.path;
    return Directory(p.join(root, 'Download'));
  }

  /// `.glsl` files sitting in the device Downloads folder (non-recursive),
  /// sorted. Empty if Downloads is absent/unreadable (no all-files permission,
  /// or nothing there).
  Future<List<String>> listDownloads() async {
    try {
      final dir = await downloadsDir();
      if (dir == null || !await dir.exists()) return const [];
      return <String>[
        await for (final e in dir.list())
          if (e is File && e.path.toLowerCase().endsWith(_ext)) e.path,
      ]..sort();
    } catch (_) {
      return const [];
    }
  }

  /// Copies every `.glsl` from Downloads into the shader folder, skipping any
  /// whose file name already exists there (no clobber). Returns the number
  /// copied. Non-destructive: the Downloads originals are left in place.
  Future<int> importFromDownloads() async {
    final sources = await listDownloads();
    if (sources.isEmpty) return 0;
    final dir = await _dir();
    var copied = 0;
    for (final src in sources) {
      final dest = p.join(dir.path, p.basename(src));
      if (await File(dest).exists()) continue;
      try {
        await File(src).copy(dest);
        copied++;
      } catch (_) {
        // unreadable / locked source → skip it, keep going.
      }
    }
    return copied;
  }
}
