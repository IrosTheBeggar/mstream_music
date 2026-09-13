import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'index_db.dart';
import 'models.dart';
import 'planner.dart';
import 'transport.dart';

/// Above this the server's `hash` is a sampled digest, not a whole-file MD5
/// (`src/db/audio-hash.js`, hash_v 2) — size is the only byte-exact check.
const int kFullHashMaxBytes = 25 * 1024 * 1024;

/// Where one server's mirror lives. All three roots sit under the same
/// download location so a finished temp file renames into place atomically
/// and a trashed file is a move, not a copy. The trash and temp trees are
/// siblings of `media/`, so the Local Files browser never lists them.
class MirrorConfig {
  final String server;
  final String mediaRoot;
  final String trashRoot;
  final String tmpRoot;

  /// Where album-art files for mirrored tracks are cached (flat, by their
  /// content-addressed server name); null = no art caching.
  final String? artRoot;

  /// Days a trashed file survives; 0 = keep forever.
  final int retentionDays;
  final bool wifiOnly;
  final int concurrency;
  final int pageSize;

  const MirrorConfig({
    required this.server,
    required this.mediaRoot,
    required this.trashRoot,
    required this.tmpRoot,
    this.artRoot,
    this.retentionDays = 30,
    this.wifiOnly = false,
    this.concurrency = 3,
    this.pageSize = 2000,
  });

  /// The standard layout under the app's download location:
  /// `<downloadDir>/media/<server>` (the same tree manual downloads use),
  /// `<downloadDir>/.mstream-trash/<server>`, `<downloadDir>/.mstream-tmp/<server>`.
  factory MirrorConfig.under(String downloadDir, String server,
          {String? artRoot,
          int retentionDays = 30,
          bool wifiOnly = false,
          int concurrency = 3,
          int pageSize = 2000}) =>
      MirrorConfig(
        server: server,
        mediaRoot: p.join(downloadDir, 'media', server),
        trashRoot: p.join(downloadDir, '.mstream-trash', server),
        tmpRoot: p.join(downloadDir, '.mstream-tmp', server),
        artRoot: artRoot,
        retentionDays: retentionDays,
        wifiOnly: wifiOnly,
        concurrency: concurrency,
        pageSize: pageSize,
      );

  /// The on-disk file for a data path (`/<vpath>/<rel>`).
  String localPathFor(String dataPath) =>
      p.normalize(p.join(mediaRoot, dataPath.replaceFirst(RegExp(r'^/+'), '')));
}

class MirrorProgress {
  final String phase;
  final int done;
  final int total;
  final int failed;
  const MirrorProgress(this.phase, this.done, this.total, this.failed);
}

/// One sync run for one server: refresh the manifest, expand the rules,
/// plan, then apply — renames and trashes first (they free space), transfers
/// through a small worker pool, each verified and stamped before it lands,
/// and a trash sweep at the end. Every outcome is written to `sync_runs`;
/// per-file failures are counted and recorded on the row, never fatal.
///
/// Runs for one server must not overlap; the app serialises them.
class MirrorRunner {
  final LibraryIndex index;
  final ManifestClient manifest;
  final Downloader downloader;

  /// The album / artist lists for offline browsing; refreshed whenever the
  /// manifest changed. Optional — the mirror works without them.
  final LibraryListsClient? lists;

  /// Album art for the mirrored tracks, cached under [MirrorConfig.artRoot].
  /// Optional and best-effort: art failures never mark a run.
  final ArtClient? art;

  /// Free bytes on the volume holding [MirrorConfig.mediaRoot]; null (or a
  /// null result) skips the preflight.
  final Future<int?> Function(String dir)? freeSpace;
  final DateTime Function() now;

  MirrorRunner({
    required this.index,
    required this.manifest,
    required this.downloader,
    this.lists,
    this.art,
    this.freeSpace,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<SyncRun> run(MirrorConfig c,
      {String trigger = 'manual',
      void Function(MirrorProgress)? onProgress,
      bool Function()? isCancelled}) async {
    final started = now().millisecondsSinceEpoch;
    var downloaded = 0, replaced = 0, renamed = 0, trashed = 0, failed = 0;
    var unchanged = 0, conflicts = 0, bytes = 0;
    String? error;
    bool cancelled() => isCancelled?.call() ?? false;

    try {
      onProgress?.call(const MirrorProgress('manifest', 0, 0, 0));
      final refreshed = await _refreshManifest(c);
      if (refreshed.changed) await _refreshLists(c);
      final scanning = refreshed.scanning;
      final remote = index.remoteTracks(c.server);
      final wanted = _expandSubscriptions(c, remote);
      final pl = plan(
        remote: remote,
        local: index.localFilesAll(c.server),
        wanted: wanted,
        options: PlanOptions(scanning: scanning),
      );
      unchanged = pl.unchanged;
      conflicts = pl.conflicts.length;
      await _preflight(c, pl);

      final bucket = _bucketName(now());
      for (final r in pl.renames) {
        if (cancelled()) break;
        await _rename(c, r);
        renamed++;
      }
      for (final f in pl.trashes) {
        if (cancelled()) break;
        await _trash(c, f, bucket);
        trashed++;
      }

      final jobs = <(RemoteTrack, bool)>[
        for (final t in pl.downloads) (t, false),
        for (final t in pl.replaces) (t, true),
      ];
      // Copies the mirror did not write: keep them if the bytes check out
      // (counted as unchanged), otherwise they join the replace queue.
      for (final a in pl.adoptions) {
        if (cancelled()) break;
        if (await _adopt(c, a)) {
          unchanged++;
        } else {
          jobs.add((a.remote, true));
        }
      }
      var next = 0;
      var done = 0;
      Future<void> worker() async {
        while (!cancelled()) {
          final k = next++;
          if (k >= jobs.length) return;
          final (t, replace) = jobs[k];
          try {
            await _fetch(c, t, replace: replace, bucket: bucket);
            if (replace) {
              replaced++;
            } else {
              downloaded++;
            }
            bytes += t.size ?? 0;
          } catch (_) {
            failed++;
          }
          done++;
          onProgress?.call(MirrorProgress('transfer', done, jobs.length, failed));
        }
      }

      await Future.wait([for (var i = 0; i < c.concurrency; i++) worker()]);
      if (!cancelled()) {
        await _fetchArt(c, [for (final t in remote) if (wanted.contains(t.path)) t]);
      }
      await _sweepTrash(c);
      await _purgeTmp(c);
    } catch (e) {
      error = '$e';
    }

    final run = SyncRun(
      server: c.server,
      started: started,
      finished: now().millisecondsSinceEpoch,
      trigger: trigger,
      downloaded: downloaded,
      replaced: replaced,
      renamed: renamed,
      trashed: trashed,
      unchanged: unchanged,
      failed: failed,
      conflicts: conflicts,
      bytes: bytes,
      error: error,
    );
    index.recordRun(run);
    onProgress?.call(MirrorProgress('done', downloaded + replaced, downloaded + replaced + failed, failed));
    return run;
  }

  // ── manifest ──────────────────────────────────────────────────────────

  /// Walks every page into the index and prunes what the server dropped.
  /// A 304 on the first page leaves the rows as they are — they are current.
  Future<({bool changed, bool scanning})> _refreshManifest(MirrorConfig c) async {
    final previous = index.meta(c.server, 'revision');
    var page = await manifest.fetchPage(
        limit: c.pageSize, ifNoneMatch: previous);
    if (page == null) return (changed: false, scanning: false);
    final rev = page.revision;
    var scanning = page.scanning;
    while (true) {
      index.upsertTracks(c.server, page!.entries, rev);
      final next = page.next;
      if (next == null) break;
      page = await manifest.fetchPage(cursor: next, limit: c.pageSize);
      if (page == null) throw StateError('manifest: 304 mid-walk');
      scanning = scanning || page.scanning;
    }
    // Rows are stamped with the FIRST page's revision even if a scan moved
    // it mid-walk: the next run then sees a changed tag and re-walks.
    index.pruneUnseen(c.server, rev);
    index.setMeta(c.server, 'revision', rev);
    return (changed: true, scanning: scanning);
  }

  /// The album / artist lists, replaced wholesale whenever the manifest
  /// moved. Best-effort: a failure leaves the previous lists in place.
  Future<void> _refreshLists(MirrorConfig c) async {
    final client = lists;
    if (client == null) return;
    try {
      index.replaceAlbums(c.server, await client.albums());
      index.replaceArtists(c.server, await client.artists());
    } catch (_) {
      // The lists are a convenience for offline browsing; the mirror itself
      // does not depend on them.
    }
  }

  /// Album art for [tracks], one fetch per distinct file not yet cached.
  /// Best-effort, sequential (art is small and the server compresses it on
  /// the fly); a failed file is simply tried again next run.
  Future<void> _fetchArt(MirrorConfig c, List<RemoteTrack> tracks) async {
    final client = art;
    final root = c.artRoot;
    if (client == null || root == null) return;
    final wanted = {for (final t in tracks) if (t.art != null) t.art!};
    if (wanted.isEmpty) return;
    await Directory(root).create(recursive: true);
    for (final file in wanted) {
      final dest = p.join(root, file);
      if (await File(dest).exists()) continue;
      final tmp = p.join(root, '.${_randomId()}.part');
      try {
        await client.fetchArt(file, tmp);
        await _move(File(tmp), dest);
      } catch (_) {
        try {
          await File(tmp).delete();
        } catch (_) {}
      }
    }
  }

  // ── rules ─────────────────────────────────────────────────────────────

  /// Expands the enabled rules to the paths they pin and rewrites their
  /// required-by edges. A3 knows `library` (a whole vpath) and `folder` (a
  /// data-path prefix); the entity kinds arrive with A6.
  Set<String> _expandSubscriptions(MirrorConfig c, List<RemoteTrack> remote) {
    final wanted = <String>{};
    for (final s in index.subscriptionsFor(c.server)) {
      final id = s.id;
      if (id == null) continue;
      final prefix = s.enabled ? _prefixFor(s) : null;
      final paths = prefix == null
          ? const <String>[]
          : [for (final t in remote) if (t.path.startsWith(prefix)) t.path];
      index.setSubscriptionFiles(id, c.server, paths);
      wanted.addAll(paths);
    }
    return wanted;
  }

  static String? _prefixFor(Subscription s) => switch (s.kind) {
        'library' => '/${s.key.replaceAll(RegExp(r'^/+|/+$'), '')}/',
        'folder' => s.key.endsWith('/') ? s.key : '${s.key}/',
        _ => null,
      };

  Future<void> _preflight(MirrorConfig c, Plan pl) async {
    final probe = freeSpace;
    if (probe == null || pl.bytesNeeded == 0) return;
    await Directory(c.mediaRoot).create(recursive: true);
    final free = await probe(c.mediaRoot);
    if (free == null) return;
    const headroom = 64 << 20;
    if (free < pl.bytesNeeded + headroom) {
      throw StateError('not enough free space: need ${pl.bytesNeeded + headroom} '
          'bytes, have $free');
    }
  }

  // ── apply ─────────────────────────────────────────────────────────────

  Future<void> _rename(MirrorConfig c, Rename r) async {
    final to = c.localPathFor(r.to.path);
    await Directory(p.dirname(to)).create(recursive: true);
    await _move(File(r.from.localPath), to);
    index.removeLocal(c.server, r.from.path);
    index.upsertLocal(_row(c, r.to, to, size: r.from.size, origin: LocalOrigin.mirror));
  }

  Future<void> _trash(MirrorConfig c, LocalFile f, String bucket) async {
    final src = File(f.localPath);
    if (await src.exists()) {
      final dest = p.join(c.trashRoot, bucket, f.path.replaceFirst(RegExp(r'^/+'), ''));
      await Directory(p.dirname(dest)).create(recursive: true);
      await _move(src, dest);
    }
    index.removeLocal(c.server, f.path);
  }

  /// Download to a temp file, verify size (and the whole-file MD5 when the
  /// server's hash is one), stamp the server's mtime, then rename into place
  /// — the old copy of a replace goes to the trash first.
  Future<void> _fetch(MirrorConfig c, RemoteTrack t,
      {required bool replace, required String bucket}) async {
    final dest = c.localPathFor(t.path);
    final old = index.localFile(c.server, t.path);
    await Directory(c.tmpRoot).create(recursive: true);
    final tmp = p.join(c.tmpRoot, '${_randomId()}.part');
    try {
      await downloader.download(t.path, tmp, requiresWiFi: c.wifiOnly);
      final f = File(tmp);
      final size = await f.length();
      if (t.size != null && size != t.size) {
        throw StateError('size mismatch: got $size, expected ${t.size}');
      }
      if (t.hash != null && size < kFullHashMaxBytes) {
        final digest = (await md5.bind(f.openRead()).first).toString();
        if (digest != t.hash) throw StateError('checksum mismatch');
      }
      if (t.modified != null) {
        await f.setLastModified(DateTime.fromMillisecondsSinceEpoch(t.modified!));
      }
      await Directory(p.dirname(dest)).create(recursive: true);
      if (replace && old != null) {
        await _trash(c, old, bucket);
      } else if (await File(dest).exists()) {
        await File(dest).delete();
      }
      await _move(f, dest);
      index.upsertLocal(_row(c, t, dest,
          size: size, origin: old?.origin ?? LocalOrigin.mirror));
    } catch (e) {
      try {
        await File(tmp).delete();
      } catch (_) {}
      index.upsertLocal(LocalFile(
        server: c.server,
        path: t.path,
        localPath: dest,
        state: LocalState.failed,
        origin: old?.origin ?? LocalOrigin.mirror,
        size: old?.size,
        mtime: old?.mtime,
        hash: old?.hash,
        error: '$e',
        verifiedAt: now().millisecondsSinceEpoch,
      ));
      rethrow;
    }
  }

  /// Verifies an existing copy against the server's row — size, and the
  /// whole-file MD5 where the server's hash is one — then stamps the server
  /// mtime and records the hash so later runs compare it like any other.
  /// False when it does not check out (or is gone): the caller replaces it.
  Future<bool> _adopt(MirrorConfig c, Adoption a) async {
    final t = a.remote;
    final f = File(a.local.localPath);
    if (!await f.exists()) return false;
    final size = await f.length();
    if (t.size != null && size != t.size) return false;
    if (t.hash != null && size < kFullHashMaxBytes) {
      final digest = (await md5.bind(f.openRead()).first).toString();
      if (digest != t.hash) return false;
    }
    if (t.modified != null) {
      await f.setLastModified(DateTime.fromMillisecondsSinceEpoch(t.modified!));
    }
    index.upsertLocal(
        _row(c, t, a.local.localPath, size: size, origin: a.local.origin));
    return true;
  }

  LocalFile _row(MirrorConfig c, RemoteTrack t, String localPath,
          {int? size, required String origin}) =>
      LocalFile(
        server: c.server,
        path: t.path,
        localPath: localPath,
        size: size ?? t.size,
        mtime: t.modified,
        hash: t.hash,
        state: LocalState.ok,
        origin: origin,
        verifiedAt: now().millisecondsSinceEpoch,
      );

  /// rename(), with a copy + delete fallback for a target on another volume.
  static Future<void> _move(File from, String to) async {
    try {
      await from.rename(to);
    } on FileSystemException {
      await from.copy(to);
      await from.delete();
    }
  }

  // ── housekeeping ──────────────────────────────────────────────────────

  Future<void> _sweepTrash(MirrorConfig c) async {
    if (c.retentionDays <= 0) return;
    final root = Directory(c.trashRoot);
    if (!await root.exists()) return;
    final cutoff = now().subtract(Duration(days: c.retentionDays));
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final day = DateTime.tryParse(p.basename(e.path));
      if (day != null && day.isBefore(cutoff)) {
        await e.delete(recursive: true);
      }
    }
  }

  Future<void> _purgeTmp(MirrorConfig c) async {
    final root = Directory(c.tmpRoot);
    if (await root.exists()) await root.delete(recursive: true);
  }

  static String _bucketName(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  static final Random _rng = Random.secure();
  static String _randomId() =>
      List.generate(12, (_) => _rng.nextInt(36).toRadixString(36)).join();
}
