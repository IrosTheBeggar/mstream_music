import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

// Progress of a background storage migration (moving a server's downloaded
// files from one storage volume to another, one file at a time).
class MigrationProgress {
  final int moved;
  final int total;
  final bool done;
  final bool failed;
  const MigrationProgress(this.moved, this.total,
      {this.done = false, this.failed = false});

  // null = indeterminate (total unknown yet).
  double? get fraction =>
      total <= 0 ? null : (moved / total).clamp(0.0, 1.0).toDouble();
}

// Moves a server's downloaded files across storage volumes in the background,
// one file at a time (rename when possible, otherwise copy then delete the
// original). Because it deletes each original only after that file is at the
// destination, an interruption can never blanket-wipe un-copied files. The
// move is recorded in a sentinel file so it resumes when the app is reopened.
class MigrationManager {
  MigrationManager._();
  static final MigrationManager _instance = MigrationManager._();
  factory MigrationManager() => _instance;

  final BehaviorSubject<MigrationProgress?> _progress =
      BehaviorSubject<MigrationProgress?>.seeded(null);
  Stream<MigrationProgress?> get progressStream => _progress.stream;

  bool _running = false;
  bool get isRunning => _running;

  Future<File> get _sentinel async {
    final dir = await getApplicationDocumentsDirectory();
    return File(path.join(dir.path, 'migration.json'));
  }

  // Begin moving [sourcePath] -> [destPath] in the background. Writes the
  // sentinel first so the move can resume if the app is killed mid-way.
  Future<void> start(String sourcePath, String destPath) async {
    if (_running) return;
    final total = await _countFiles(Directory(sourcePath));
    try {
      final s = await _sentinel;
      await s.writeAsString(jsonEncode(
          {'source': sourcePath, 'dest': destPath, 'total': total}));
    } catch (_) {}
    unawaited(_run(Directory(sourcePath), Directory(destPath), total));
  }

  // Resume an interrupted move on app startup, if a sentinel is present.
  Future<void> resumeIfNeeded() async {
    try {
      final s = await _sentinel;
      if (!s.existsSync()) return;
      final data = jsonDecode(await s.readAsString()) as Map<String, dynamic>;
      final source = Directory(data['source'] as String);
      final dest = Directory(data['dest'] as String);
      final total = (data['total'] as int?) ?? 0;
      if (!source.existsSync()) {
        await s.delete(); // nothing left to move
        return;
      }
      unawaited(_run(source, dest, total));
    } catch (_) {
      // Corrupt/unreadable sentinel — drop it so we don't loop on it.
      try {
        final s = await _sentinel;
        if (s.existsSync()) await s.delete();
      } catch (_) {}
    }
  }

  Future<int> _countFiles(Directory d) async {
    int n = 0;
    try {
      if (!d.existsSync()) return 0;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File) n++;
      }
    } catch (_) {}
    return n;
  }

  Future<void> _run(Directory source, Directory dest, int total) async {
    if (_running) return;
    _running = true;
    try {
      // moved = already-moved count, so a resumed run shows true progress.
      final remaining = await _countFiles(source);
      int moved = (total - remaining).clamp(0, total);
      _progress.add(MigrationProgress(moved, total));

      final files = <File>[];
      try {
        await for (final e
            in source.list(recursive: true, followLinks: false)) {
          if (e is File) files.add(e);
        }
      } catch (_) {}

      for (final f in files) {
        if (!f.existsSync()) continue; // already moved on a prior pass
        final rel = path.relative(f.path, from: source.path);
        final destPath = path.join(dest.path, rel);
        await Directory(path.dirname(destPath)).create(recursive: true);
        try {
          await f.rename(destPath); // same-volume fast path
        } catch (_) {
          await f.copy(destPath); // cross-volume: copy then drop the original
          await f.delete();
        }
        moved++;
        _progress.add(MigrationProgress(moved.clamp(0, total), total));
      }

      // Remove the source tree only if it's now empty — a file that arrived
      // after our scan (e.g. an in-flight download) is preserved, not wiped.
      if (await _countFiles(source) == 0) {
        try {
          if (source.existsSync()) await source.delete(recursive: true);
        } catch (_) {}
      }
      try {
        final s = await _sentinel;
        if (s.existsSync()) await s.delete();
      } catch (_) {}

      _progress.add(MigrationProgress(total, total, done: true));
      await Future.delayed(const Duration(seconds: 3));
      _progress.add(null); // clear the banner
    } catch (_) {
      // Leave the sentinel in place so it retries next launch.
      _progress.add(MigrationProgress(0, total, failed: true));
    } finally {
      _running = false;
    }
  }
}
