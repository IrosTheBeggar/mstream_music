import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_manager.dart';

/// Album art the mirror fetched for its tracks, one flat folder per server
/// under `<documents>/art/<server>/<file>` — the file names are the server's
/// content-addressed ones, so a cached file never goes stale. Kept as an
/// in-memory set per server so a list of rows costs no stats.
class ArtCache {
  ArtCache._();
  static final ArtCache _instance = ArtCache._();
  factory ArtCache() => _instance;

  String? _root;
  final Map<String, Set<String>> _files = {};

  String? get root => _root;

  /// Points the cache at `<documents>/art` (or [root]) and lists what is
  /// already there. Never throws.
  Future<void> init({String? root}) async {
    try {
      _root = root ?? p.join((await getApplicationDocumentsDirectory()).path, 'art');
      final dir = Directory(_root!);
      if (!await dir.exists()) return;
      await for (final e in dir.list()) {
        if (e is Directory) await reload(p.basename(e.path));
      }
    } catch (e) {
      appLog('[art] cache unavailable: $e');
    }
  }

  String? dirFor(String server) => _root == null ? null : p.join(_root!, server);

  /// Re-lists one server's folder (after a mirror run).
  Future<void> reload(String server) async {
    final dir = dirFor(server);
    if (dir == null) return;
    final names = <String>{};
    try {
      await for (final e in Directory(dir).list()) {
        final name = p.basename(e.path);
        if (e is File && !name.startsWith('.')) names.add(name);
      }
    } catch (_) {
      // Missing folder: nothing cached yet.
    }
    _files[server] = names;
  }

  /// The cached file for [artFile], or null when this device has none.
  String? pathFor(String server, String artFile) {
    final names = _files[server];
    if (names == null || !names.contains(artFile)) return null;
    return p.join(dirFor(server)!, artFile);
  }

  int count(String server) => _files[server]?.length ?? 0;
}
