import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:library_mirror/library_mirror.dart';
import 'package:path_provider/path_provider.dart';

import '../objects/server.dart';
import 'file_explorer.dart';
import 'log_manager.dart';
import 'server_list.dart';

/// The app's handle on the local library index (packages/library_mirror):
/// opens it at boot, keeps the local-copy rows in step with downloads and
/// deletions, and imports the downloads that predate it once per server.
///
/// Optional by design: if the bundled SQLite fails to load, or the file was
/// written by a newer app, the index stays null and every caller keeps the
/// existence checks it used before — nothing user-facing depends on it yet
/// (A2 of BACKUP_SYNC_IMPLEMENTATION.md; the mirror engine and offline
/// browsing build on it).
class LibraryIndexManager {
  LibraryIndexManager._();
  static final LibraryIndexManager _instance = LibraryIndexManager._();
  factory LibraryIndexManager() => _instance;

  static const String dbFileName = 'library_index.db';

  LibraryIndex? _index;
  LibraryIndex? get index => _index;
  bool get available => _index != null;

  /// Opens `<documents>/library_index.db` (next to servers.json), or [path].
  /// Never throws: a failure logs and leaves the manager unavailable.
  Future<void> open({String? path}) async {
    if (_index != null) return;
    try {
      final p = path ??
          '${(await getApplicationDocumentsDirectory()).path}/$dbFileName';
      _index = LibraryIndex.open(p);
      appLog('[index] open: $p');
    } catch (e) {
      appLog('[index] unavailable: $e');
    }
  }

  void close() {
    _index?.close();
    _index = null;
  }

  /// One-time import of the downloads that predate the index: every file
  /// under `<downloadDir>/media/<localname>` becomes a `manual` row (a user
  /// asked for it, or it predates the auto ledger and is grandfathered as
  /// manual — the same rule AutoDownloadLedger applies). Idempotent per
  /// server; a server whose location is unavailable right now (SD card
  /// out) is retried on the next boot. The walk runs on a worker isolate.
  Future<void> importExistingDownloads(
      {List<Server>? servers,
      Future<Directory?> Function(Server)? dirFor}) async {
    final ix = _index;
    if (ix == null) return;
    if (servers == null) await ServerManager().ensureLoaded();
    final list = servers ?? ServerManager().serverList;
    final resolve = dirFor ?? _downloadDir;
    for (final s in list) {
      if (ix.meta(s.localname, 'imported') != null) continue;
      Directory? dir;
      try {
        dir = await resolve(s);
      } catch (e) {
        appLog('[index] import skipped for ${s.localname}: $e');
      }
      if (dir == null) continue;
      final root = '${dir.path}/media/${s.localname}';
      final found = await Isolate.run(() => walkDownloadTree(root));
      final now = DateTime.now().millisecondsSinceEpoch;
      ix.upsertLocals([
        for (final f in found)
          LocalFile(
            server: s.localname,
            path: f.$1,
            localPath: f.$2,
            size: f.$3,
            mtime: f.$4,
            state: LocalState.ok,
            origin: LocalOrigin.manual,
            verifiedAt: now,
          ),
      ]);
      ix.setMeta(s.localname, 'imported', '${found.length}');
      appLog('[index] imported ${found.length} existing downloads for '
          '${s.localname}');
    }
  }

  static Future<Directory?> _downloadDir(Server s) =>
      FileExplorer().getDownloadDir(s.storageMode, s.storageBasePath);

  /// A download just landed at [localPath].
  void recordDownloaded(String server, String path, String localPath,
      {required bool auto}) {
    final ix = _index;
    if (ix == null) return;
    int? size, mtime;
    try {
      final st = File(localPath).statSync();
      size = st.size;
      mtime = st.modified.millisecondsSinceEpoch;
    } catch (_) {}
    ix.upsertLocal(LocalFile(
      server: server,
      path: path,
      localPath: localPath,
      size: size,
      mtime: mtime,
      state: LocalState.ok,
      origin: auto ? LocalOrigin.auto : LocalOrigin.manual,
      verifiedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// A user explicitly downloaded a track the auto cache already held:
  /// manual wins, so the row can never be evicted (mirrors the ledger).
  void promoteToManual(String server, String path) =>
      _index?.setOrigin(server, path, LocalOrigin.manual, ifOrigin: LocalOrigin.auto);

  /// The file at [localPath] is gone (user delete, cap eviction).
  void forgetLocalPath(String? server, String localPath) =>
      _index?.removeLocalByLocalPath(server, localPath);

  /// The folder at [dirPath] is gone.
  void forgetLocalUnder(String? server, String dirPath) =>
      _index?.removeLocalUnder(server, dirPath);

  void removeServer(String server) => _index?.removeServer(server);
}

/// Every file under [root] (the `<downloadDir>/media/<localname>` tree) as
/// `(dataPath, absolutePath, size, mtimeMs)`, where dataPath is the server's
/// `/<vpath>/<rel>` form read straight off the tree layout. Skips the mirror
/// engine's own temp / trash entries. Top-level and pure dart:io so it can
/// run on a worker isolate.
List<(String, String, int, int)> walkDownloadTree(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final out = <(String, String, int, int)>[];
  for (final e in dir.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final rel = e.path.substring(root.length).replaceAll('\\', '/');
    if (rel.contains('/.mstream-')) continue;
    final st = e.statSync();
    out.add((
      rel.startsWith('/') ? rel : '/$rel',
      e.path,
      st.size,
      st.modified.millisecondsSinceEpoch,
    ));
  }
  return out;
}
