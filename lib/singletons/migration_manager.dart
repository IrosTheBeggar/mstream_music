import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

// FAT/exFAT (typical removable SD cards) reject these characters in file and
// directory names; '/' is the legal path separator between segments.
final RegExp _fatIllegalChars = RegExp(r'[<>:"|?*\\\x00-\x1f]');

// True if [relativePath] holds a character FAT/exFAT can't store — such files
// can't be saved to a typical SD card.
bool hasFatIllegalChars(String relativePath) =>
    _fatIllegalChars.hasMatch(relativePath);

// Progress of a background storage migration (moving a server's downloaded
// files from one storage volume to another, one file at a time).
class MigrationProgress {
  final int moved; // files moved so far
  final int total; // total files
  final int movedBytes;
  final int totalBytes;
  final int skipped; // files skipped (names unsupported on the destination)
  final bool done;
  final bool failed; // stopped on an error; awaiting Retry/Cancel
  const MigrationProgress(this.moved, this.total,
      {this.movedBytes = 0,
      this.totalBytes = 0,
      this.skipped = 0,
      this.done = false,
      this.failed = false});

  // Byte-based when known (smoother on big files), else file-count, else
  // indeterminate (null).
  double? get fraction {
    if (totalBytes > 0) {
      return (movedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
    }
    if (total > 0) return (moved / total).clamp(0.0, 1.0).toDouble();
    return null;
  }
}

// Moves a server's downloaded files across storage volumes in the background,
// one file at a time (rename when possible, otherwise copy then delete the
// original). Deleting each original only after its copy lands means an
// interruption can never blanket-wipe un-copied files. A sentinel file records
// the move so it resumes when the app is reopened — but a move that *errored*
// (e.g. out of space) is not auto-retried; it waits for the user to Retry or
// Cancel from the banner.
class MigrationManager {
  MigrationManager._();
  static final MigrationManager _instance = MigrationManager._();
  factory MigrationManager() => _instance;

  static const MethodChannel _channel = MethodChannel('mstream/storage');

  final BehaviorSubject<MigrationProgress?> _progress =
      BehaviorSubject<MigrationProgress?>.seeded(null);
  Stream<MigrationProgress?> get progressStream => _progress.stream;

  bool _running = false;
  bool get isRunning => _running;
  bool _cancelRequested = false;

  Future<File> get _sentinel async {
    final dir = await getApplicationDocumentsDirectory();
    return File(path.join(dir.path, 'migration.json'));
  }

  // Free bytes on the volume holding [dirPath] (native StatFs), or null if it
  // can't be determined.
  Future<int?> freeBytes(String dirPath) async {
    try {
      return await _channel.invokeMethod<int>('freeBytes', {'path': dirPath});
    } catch (_) {
      return null;
    }
  }

  // Start/stop the foreground service that keeps the process alive during a
  // move (so it survives backgrounding). Non-fatal — the move runs regardless.
  Future<void> _setService(bool active) async {
    try {
      await _channel.invokeMethod(active ? 'startMove' : 'stopMove');
    } catch (_) {}
  }

  // Whether [dirPath]'s filesystem rejects FAT-illegal characters (typical of
  // an SD card). Probes by writing a normal file (must succeed) then one with
  // a '?' (fails on FAT). Defaults to false (don't skip) if it can't tell.
  Future<bool> _isFatLike(String dirPath) async {
    try {
      final ok = File(path.join(dirPath, '.mstream_probe'));
      await ok.writeAsString('');
      await ok.delete();
    } catch (_) {
      return false; // can't write here at all — not a charset limit
    }
    try {
      final bad = File(path.join(dirPath, '.mstream_probe_q?'));
      await bad.writeAsString('');
      await bad.delete();
      return false; // illegal char accepted → not FAT
    } catch (_) {
      return true; // normal name OK but '?' rejected → FAT-like
    }
  }

  // Begin moving [sourcePath] -> [destPath]. [totalFiles]/[totalBytes] are the
  // already-computed source size (from the dialog) so we don't re-walk.
  Future<void> start(String sourcePath, String destPath, int totalFiles,
      int totalBytes) async {
    if (_running) return;
    try {
      final s = await _sentinel;
      await s.writeAsString(jsonEncode({
        'source': sourcePath,
        'dest': destPath,
        'total': totalFiles,
        'totalBytes': totalBytes,
        'failures': 0,
      }));
    } catch (_) {}
    unawaited(
        _run(Directory(sourcePath), Directory(destPath), totalFiles, totalBytes));
  }

  // On app startup: auto-resume an interrupted move — UNLESS it previously
  // errored (failures > 0), in which case surface an actionable banner and
  // wait for Retry/Cancel rather than looping forever.
  Future<void> resumeIfNeeded() async {
    try {
      final s = await _sentinel;
      if (!s.existsSync()) return;
      final data = jsonDecode(await s.readAsString()) as Map<String, dynamic>;
      final source = Directory(data['source'] as String);
      final total = (data['total'] as int?) ?? 0;
      final totalBytes = (data['totalBytes'] as int?) ?? 0;
      final failures = (data['failures'] as int?) ?? 0;
      if (!source.existsSync()) {
        await s.delete(); // nothing left to move
        return;
      }
      if (failures > 0) {
        _progress.add(
            MigrationProgress(0, total, totalBytes: totalBytes, failed: true));
        return;
      }
      unawaited(
          _run(source, Directory(data['dest'] as String), total, totalBytes));
    } catch (_) {
      try {
        final s = await _sentinel;
        if (s.existsSync()) await s.delete();
      } catch (_) {}
    }
  }

  // User tapped Retry on the failed banner — clear the failure count and run.
  Future<void> retry() async {
    if (_running) return;
    try {
      final s = await _sentinel;
      if (!s.existsSync()) return;
      final data = jsonDecode(await s.readAsString()) as Map<String, dynamic>;
      data['failures'] = 0;
      await s.writeAsString(jsonEncode(data));
      unawaited(_run(Directory(data['source'] as String),
          Directory(data['dest'] as String), (data['total'] as int?) ?? 0,
          (data['totalBytes'] as int?) ?? 0));
    } catch (_) {}
  }

  // User tapped Cancel — stop, drop the sentinel, clear the banner. Files
  // already moved stay at the destination; the rest stay at the source.
  Future<void> cancel() async {
    _cancelRequested = true;
    try {
      final s = await _sentinel;
      if (s.existsSync()) await s.delete();
    } catch (_) {}
    _progress.add(null);
  }

  Future<void> _recordFailure() async {
    try {
      final s = await _sentinel;
      if (!s.existsSync()) return;
      final data = jsonDecode(await s.readAsString()) as Map<String, dynamic>;
      data['failures'] = ((data['failures'] as int?) ?? 0) + 1;
      await s.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _run(
      Directory source, Directory dest, int total, int totalBytes) async {
    if (_running) return;
    _running = true;
    _cancelRequested = false;
    bool succeeded = false;
    try {
      // One walk: gather the remaining files + their sizes.
      final files = <File>[];
      final sizes = <int>[];
      int remainingBytes = 0;
      try {
        await for (final e
            in source.list(recursive: true, followLinks: false)) {
          if (e is File) {
            final sz = await e.length();
            files.add(e);
            sizes.add(sz);
            remainingBytes += sz;
          }
        }
      } catch (_) {}

      int moved = (total - files.length).clamp(0, total);
      int movedBytes = (totalBytes - remainingBytes).clamp(0, totalBytes);
      _progress.add(MigrationProgress(moved, total,
          movedBytes: movedBytes, totalBytes: totalBytes));

      // Hold a foreground service for the duration so backgrounding the app
      // doesn't freeze the move; detect a FAT/exFAT destination (SD card) so
      // files with unsupported names are skipped, not fatal.
      bool fatLike = false;
      if (files.isNotEmpty) {
        try {
          await dest.create(recursive: true);
        } catch (_) {}
        fatLike = await _isFatLike(dest.path);
        await _setService(true);
      }

      int lastPct = -1;
      int skipped = 0;
      bool canceled = false;
      for (int i = 0; i < files.length; i++) {
        if (_cancelRequested) {
          canceled = true;
          break;
        }
        final f = files[i];
        if (!f.existsSync()) continue;
        final rel = path.relative(f.path, from: source.path);
        // Can't store this name on a FAT/exFAT card — leave it at the source
        // rather than failing the whole move.
        if (fatLike && hasFatIllegalChars(rel)) {
          skipped++;
          continue;
        }
        final destPath = path.join(dest.path, rel);
        await Directory(path.dirname(destPath)).create(recursive: true);
        try {
          await f.rename(destPath); // same-volume fast path
        } catch (_) {
          try {
            await f.copy(destPath);
          } catch (e) {
            // Out of space / write error: clean up the partial destination
            // file and keep the original. Propagate so the run records a
            // failure (no blanket delete of un-copied files).
            try {
              final p = File(destPath);
              if (p.existsSync()) await p.delete();
            } catch (_) {}
            rethrow;
          }
          await f.delete();
        }
        moved++;
        movedBytes += sizes[i];
        final pct = totalBytes > 0
            ? (movedBytes * 100) ~/ totalBytes
            : (total > 0 ? (moved * 100) ~/ total : 100);
        if (pct != lastPct) {
          lastPct = pct;
          _progress.add(MigrationProgress(moved, total,
              movedBytes: movedBytes, totalBytes: totalBytes));
        }
      }

      if (canceled) {
        _progress.add(null); // sentinel already removed by cancel()
        return;
      }

      // Remove the source tree only if it's now empty — a file that arrived
      // mid-move (e.g. an in-flight download) is preserved, not wiped.
      final hasLeftovers = await source
          .list(recursive: true, followLinks: false)
          .any((e) => e is File);
      if (!hasLeftovers) {
        try {
          if (source.existsSync()) await source.delete(recursive: true);
        } catch (_) {}
      }
      try {
        final s = await _sentinel;
        if (s.existsSync()) await s.delete();
      } catch (_) {}

      _progress.add(MigrationProgress(total, total,
          movedBytes: totalBytes,
          totalBytes: totalBytes,
          skipped: skipped,
          done: true));
      succeeded = true;
    } catch (_) {
      await _recordFailure();
      _progress.add(
          MigrationProgress(0, total, totalBytes: totalBytes, failed: true));
    } finally {
      _running = false;
      unawaited(_setService(false));
    }
    // Cosmetic: clear the "done" banner after a moment — outside the busy
    // window, so a new move can start immediately.
    if (succeeded) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_running) _progress.add(null);
    }
  }
}
