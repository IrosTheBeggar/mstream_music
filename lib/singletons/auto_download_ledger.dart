import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../objects/auto_download_entry.dart';
import 'log_manager.dart';

/// Persistent, ordered record of auto-downloaded tracks (keep-queue-offline),
/// so the auto-download cap can evict the oldest orphans once the total grows
/// past the user's limit. Ordered oldest-first (newest appended), mirroring the
/// single-JSON-file approach of QueueStore / servers.json.
///
/// Only the sweep records here; manual downloads never do and actively forget a
/// track they touch, so an evictable entry is always something the app chose to
/// cache on the user's behalf — never a file they asked for.
class AutoDownloadLedger {
  static final AutoDownloadLedger _instance = AutoDownloadLedger._();
  factory AutoDownloadLedger() => _instance;
  AutoDownloadLedger._();

  // Oldest first, newest last — the FIFO eviction order.
  final List<AutoDownloadEntry> _entries = [];
  bool _loaded = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/auto_downloads.json');
  }

  /// Read the ledger from disk once. Idempotent; safe to call on every entry
  /// point that needs it.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final entry =
                AutoDownloadEntry.fromJson(Map<String, dynamic>.from(e));
            if (entry != null) _entries.add(entry);
          }
        }
      }
    } catch (e) {
      appLog('[auto-dl] ledger load failed: $e');
    }
  }

  int get length => _entries.length;

  /// Record an auto-download completion. Re-recording a tracked track moves it
  /// to newest (and updates its localPath after a storage-location change), so
  /// a re-download doesn't make an old entry look freshly cached.
  Future<void> record(String server, String path, String localPath) async {
    await load();
    _entries.removeWhere((e) => e.server == server && e.path == path);
    _entries.add(AutoDownloadEntry(server, path, localPath));
    await _persist();
  }

  /// Drop a track from the ledger without deleting its file — used when the
  /// user downloads it manually (manual wins) and when the cap evicts it.
  /// Returns whether anything was removed.
  Future<bool> forget(String server, String path) async {
    await load();
    final before = _entries.length;
    _entries.removeWhere((e) => e.server == server && e.path == path);
    if (_entries.length == before) return false;
    await _persist();
    return true;
  }

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
      selectEvictions(_entries, cap, isProtected: isProtected);

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(
          jsonEncode(_entries.map((e) => e.toJson()).toList()));
    } catch (e) {
      appLog('[auto-dl] ledger persist failed: $e');
    }
  }
}
