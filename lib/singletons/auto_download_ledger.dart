import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../objects/auto_download_entry.dart';
import 'library_index.dart';
import 'log_manager.dart';

/// The keep-queue-offline cache's eviction order, read off the library
/// index: every auto-download lands there as an `auto` row (A2), and the cap
/// evicts the oldest of them once the total grows past the user's limit.
///
/// Only the sweep's downloads are `auto`; a manual download of the same
/// track re-labels the row `manual` (manual wins), so an evictable entry is
/// always something the app chose to cache on the user's behalf — never a
/// file they asked for. Downloads that predate the index were imported as
/// `manual`, so they cannot be evicted either.
///
/// Until A8 this was its own JSON file (`auto_downloads.json`); [load] folds
/// that file into the index once and deletes it. Without the index (SQLite
/// failed to load) there is no ledger: nothing is evicted.
class AutoDownloadLedger {
  static final AutoDownloadLedger _instance = AutoDownloadLedger._();
  factory AutoDownloadLedger() => _instance;
  AutoDownloadLedger._();

  Future<void>? _loading;

  /// Migrates the pre-A8 JSON ledger into the index, once. Idempotent;
  /// concurrent callers await the same in-flight migration.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (!LibraryIndexManager().available) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      await migrateFrom(File('${dir.path}/auto_downloads.json'));
    } catch (e) {
      appLog('[auto-dl] ledger migration failed: $e');
    }
  }

  /// Folds [json] — the old ledger, oldest first — into the index and
  /// deletes it. A missing file is nothing to do. Public for tests.
  Future<void> migrateFrom(File json) async {
    if (!await json.exists()) return;
    final raw = jsonDecode(await json.readAsString());
    final entries = <AutoDownloadEntry>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final entry =
              AutoDownloadEntry.fromJson(Map<String, dynamic>.from(e));
          if (entry != null) entries.add(entry);
        }
      }
    }
    LibraryIndexManager().adoptAutoLedger([
      for (final e in entries)
        (server: e.server, path: e.path, localPath: e.localPath),
    ]);
    await json.delete();
    appLog('[auto-dl] folded ${entries.length} ledger entries into the index');
  }

  /// The auto-downloaded tracks, oldest first.
  List<AutoDownloadEntry> get entries => [
        for (final f in LibraryIndexManager().autoDownloads())
          AutoDownloadEntry(f.server, f.path, f.localPath)
      ];

  /// Takes a track out of the evictable set without deleting its file — the
  /// user downloaded it manually, so it is theirs now (manual wins). A no-op
  /// for anything that is not an auto row.
  void forget(String server, String path) =>
      LibraryIndexManager().promoteToManual(server, path);

  /// Oldest-first entries to evict so the total count drops to [cap], skipping
  /// any the current queue still needs. Pure over its inputs (unit-tested):
  /// - `cap <= 0` keeps everything (unlimited).
  /// - protected entries (in the queue, incl. the playing track) are never
  ///   selected, even if that leaves the total above the cap — the queue must
  ///   stay fully offline-available; the cap only bounds the extra cache.
  static List<AutoDownloadEntry> selectEvictions(
      List<AutoDownloadEntry> entries, int cap,
      {required bool Function(String server, String path) isProtected}) {
    if (cap <= 0) return const [];
    var over = entries.length - cap;
    if (over <= 0) return const [];
    final out = <AutoDownloadEntry>[];
    for (final e in entries) {
      // oldest first
      if (over <= 0) break;
      if (isProtected(e.server, e.path)) continue;
      out.add(e);
      over--;
    }
    return out;
  }

  List<AutoDownloadEntry> evictionsFor(
          int cap, bool Function(String server, String path) isProtected) =>
      selectEvictions(entries, cap, isProtected: isProtected);
}
