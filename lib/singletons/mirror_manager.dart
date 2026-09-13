import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';

import '../objects/server.dart';
import '../util/connectivity_probe.dart';
import '../util/decode_json.dart';
import '../util/stream_url.dart';
import 'art_cache.dart';
import 'browser_list.dart';
import 'file_explorer.dart';
import 'library_index.dart';
import 'log_manager.dart';
import 'server_list.dart';

/// background_downloader group of the mirror's transfers. DownloadManager
/// hands their updates to [MirrorManager.onTaskUpdate] instead of the
/// manual-download path: they complete into a temp tree the runner owns.
const String kMirrorGroup = 'mirror';

/// What the Library copy screen shows for one server.
class MirrorStatus {
  final bool running;
  final MirrorProgress? progress;
  final SyncRun? lastRun;

  /// Mirror-owned files on disk, their total size, and rows whose last
  /// transfer failed.
  final int files;
  final int bytes;
  final int failed;

  const MirrorStatus({
    required this.running,
    required this.progress,
    required this.lastRun,
    required this.files,
    required this.bytes,
    required this.failed,
  });
}

/// Runs the mirror engine for every server with a "keep a full copy" rule:
/// once shortly after boot, every six hours while the app is open, and on
/// demand. One run per server at a time. Also owns the plumbing between the
/// engine's [Downloader] and background_downloader.
///
/// A3 of BACKUP_SYNC_IMPLEMENTATION.md. Nothing here runs without the index
/// (see LibraryIndexManager) or on a server without the `sync` flag.
class MirrorManager {
  MirrorManager._();
  static final MirrorManager _instance = MirrorManager._();
  factory MirrorManager() => _instance;

  static const Duration bootDelay = Duration(minutes: 2);
  static const Duration period = Duration(hours: 6);

  final BehaviorSubject<Map<String, MirrorStatus>> _status =
      BehaviorSubject.seeded(const {});
  Stream<Map<String, MirrorStatus>> get statusStream => _status.stream;
  Map<String, MirrorStatus> get current => _status.value;
  MirrorStatus? statusFor(Server s) => _status.value[s.localname];

  final Set<String> _running = {};
  final Set<String> _cancelRequested = {};
  final Map<String, Completer<void>> _tasks = {};
  Timer? _bootTimer;
  Timer? _periodicTimer;

  LibraryIndex? get _index => LibraryIndexManager().index;

  Future<void> init() async {
    if (_index == null) return;
    // Transfers left over from a previous process would complete into a temp
    // tree nobody is waiting on; the next run re-plans them anyway.
    try {
      final stale = await FileDownloader().allTasks(group: kMirrorGroup);
      if (stale.isNotEmpty) {
        await FileDownloader()
            .cancelTasksWithIds([for (final t in stale) t.taskId]);
        appLog('[mirror] cancelled ${stale.length} stale transfers');
      }
    } catch (e) {
      appLog('[mirror] stale-transfer sweep failed: $e');
    }
    _bootTimer = Timer(bootDelay, () => syncAll(trigger: 'boot'));
    _periodicTimer = Timer.periodic(period, (_) => syncAll(trigger: 'periodic'));
    await ServerManager().ensureLoaded();
    for (final s in ServerManager().serverList) {
      _publish(s.localname);
    }
  }

  void dispose() {
    _bootTimer?.cancel();
    _periodicTimer?.cancel();
  }

  // ── rules ─────────────────────────────────────────────────────────────

  bool keepsFullCopy(Server s, String vpath) =>
      (_index?.subscriptionsFor(s.localname) ?? const []).any(
          (r) => r.kind == 'library' && r.key == vpath && r.enabled);

  bool hasRules(Server s) =>
      (_index?.subscriptionsFor(s.localname) ?? const []).any((r) => r.enabled);

  /// Adds or removes the whole-library rule for [vpath] and syncs right away:
  /// on, so the copy starts filling; off, so the files no rule wants any more
  /// move to the trash (recoverable for the retention period).
  void setKeepFullCopy(Server s, String vpath, bool on) {
    final ix = _index;
    if (ix == null) return;
    if (on) {
      ix.addSubscription(
          Subscription(server: s.localname, kind: 'library', key: vpath));
    } else {
      for (final r in ix.subscriptionsFor(s.localname)) {
        if (r.kind == 'library' && r.key == vpath && r.id != null) {
          ix.removeSubscription(r.id!);
        }
      }
    }
    _publish(s.localname);
    unawaited(sync(s, trigger: 'rule'));
  }

  // ── runs ──────────────────────────────────────────────────────────────

  /// Every server that speaks the manifest, rules or not: without a rule a
  /// run is just the index refresh (manifest + lists, a 304 most of the time)
  /// that offline browsing lives on; transfers need a rule.
  Future<void> syncAll({required String trigger}) async {
    if (!await hasConnectivity()) return;
    await ServerManager().ensureLoaded();
    for (final s in List<Server>.of(ServerManager().serverList)) {
      if (s.syncAvailable != true || s.browseOffline) continue;
      await sync(s, trigger: trigger);
    }
  }

  bool isRunning(Server s) => _running.contains(s.localname);

  void cancel(Server s) {
    if (isRunning(s)) _cancelRequested.add(s.localname);
  }

  /// One run for [s]; null when it could not start (no index, already
  /// running, no `sync` flag, download location unavailable).
  Future<SyncRun?> sync(Server s, {String trigger = 'manual'}) async {
    final ix = _index;
    final name = s.localname;
    if (ix == null || _running.contains(name)) return null;
    if (s.syncAvailable != true) {
      appLog('[mirror] $name: server has no sync manifest');
      return null;
    }
    Directory? dir;
    try {
      dir = await FileExplorer().getDownloadDir(s.storageMode, s.storageBasePath);
    } catch (e) {
      appLog('[mirror] $name: download location lookup failed: $e');
    }
    if (dir == null) {
      appLog('[mirror] $name: download location unavailable');
      return null;
    }
    final cfg = MirrorConfig.under(dir.path, name,
        artRoot: ArtCache().dirFor(name),
        retentionDays: s.mirrorRetentionDays,
        wifiOnly: s.mirrorWifiOnly && (Platform.isAndroid || Platform.isIOS));
    _running.add(name);
    _cancelRequested.remove(name);
    _publish(name);
    final runner = MirrorRunner(
      index: ix,
      manifest: ServerManifestClient(s),
      downloader: _MirrorDownloader(s, this),
      lists: ServerListsClient(s),
      art: ServerArtClient(s),
    );
    try {
      final run = await runner.run(cfg,
          trigger: trigger,
          onProgress: (pr) => _publish(name, progress: pr),
          isCancelled: () => _cancelRequested.contains(name));
      appLog('[mirror] $name: ${run.error ?? 'ok'} — ${run.downloaded} new, '
          '${run.replaced} replaced, ${run.renamed} renamed, ${run.trashed} '
          'trashed, ${run.failed} failed, ${run.unchanged} unchanged');
      return run;
    } catch (e) {
      appLog('[mirror] $name: run crashed: $e');
      return null;
    } finally {
      _running.remove(name);
      _cancelRequested.remove(name);
      await ArtCache().reload(name);
      _publish(name);
      // Files landed or left: the browser's badges are existence-derived.
      unawaited(BrowserManager().refreshDownloadStatus(s));
    }
  }

  void _publish(String server, {MirrorProgress? progress}) {
    final ix = _index;
    if (ix == null) return;
    final st = MirrorStatus(
      running: _running.contains(server),
      progress: progress,
      lastRun: ix.lastRun(server),
      files: ix.localCount(server, origin: LocalOrigin.mirror),
      bytes: ix.localBytes(server, origin: LocalOrigin.mirror),
      failed: ix.localCount(server, state: LocalState.failed),
    );
    _status.add({..._status.value, server: st});
  }

  // ── downloader plumbing ───────────────────────────────────────────────

  /// Terminal status of a mirror-group task → the completer its
  /// [_MirrorDownloader.download] call is waiting on.
  void onTaskUpdate(TaskUpdate u) {
    if (u is! TaskStatusUpdate) return;
    final done = _tasks[u.task.taskId];
    if (done == null || done.isCompleted) return;
    switch (u.status) {
      case TaskStatus.complete:
        done.complete();
      case TaskStatus.failed:
        done.completeError(StateError(
            'download failed: ${u.exception?.description ?? 'unknown error'}'));
      case TaskStatus.notFound:
        done.completeError(StateError('not found on the server'));
      case TaskStatus.canceled:
        done.completeError(StateError('cancelled'));
      default:
        break; // enqueued / running / paused / waitingToRetry
    }
  }
}

/// `POST /api/v1/sync/manifest` over the server's API transport (HTTP or the
/// iroh loopback), with the JWT in the header and `If-None-Match` for the
/// 304 fast path. Its own client: it must never touch the browser's loading
/// bar the way makeServerCall does.
class ServerManifestClient implements ManifestClient {
  final Server server;
  final http.Client Function() _newClient;

  ServerManifestClient(this.server, {http.Client Function()? client})
      : _newClient = client ?? http.Client.new;

  @override
  Future<ManifestPage?> fetchPage(
      {int? cursor, int limit = 2000, String? ifNoneMatch}) async {
    final client = _newClient();
    final headers = {
      'Content-Type': 'application/json',
      'x-access-token': server.authToken ?? '',
    };
    if (ifNoneMatch != null) headers['If-None-Match'] = '"$ifNoneMatch"';
    try {
      final res = await client
          .post(server.apiUri('/api/v1/sync/manifest'),
              headers: headers,
              body: jsonEncode({'cursor': ?cursor, 'limit': limit}))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 304) return null;
      if (res.statusCode != 200) {
        throw HttpException('manifest: HTTP ${res.statusCode}');
      }
      final body = await decodeJsonBody(res.body);
      return ManifestPage.fromJson((body as Map).cast<String, dynamic>());
    } finally {
      client.close();
    }
  }
}

/// `GET /api/v1/db/albums` and `/db/artists` for the offline index — the
/// same two calls the browser makes, minus the browser.
class ServerListsClient implements LibraryListsClient {
  final Server server;
  final http.Client Function() _newClient;

  ServerListsClient(this.server, {http.Client Function()? client})
      : _newClient = client ?? http.Client.new;

  Future<dynamic> _get(String location) async {
    final client = _newClient();
    try {
      final res = await client
          .get(server.apiUri(location),
              headers: {'x-access-token': server.authToken ?? ''})
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('$location: HTTP ${res.statusCode}');
      }
      return await decodeJsonBody(res.body);
    } finally {
      client.close();
    }
  }

  Future<dynamic> _post(String location, Map<String, dynamic> body) async {
    final client = _newClient();
    try {
      final res = await client
          .post(server.apiUri(location),
              body: jsonEncode(body),
              headers: {
                'Content-Type': 'application/json',
                'x-access-token': server.authToken ?? ''
              })
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('$location: HTTP ${res.statusCode}');
      }
      return await decodeJsonBody(res.body);
    } finally {
      client.close();
    }
  }

  static String _dataPath(String fp) => fp.startsWith('/') ? fp : '/$fp';

  @override
  Future<Map<String, int>> genres() async {
    final res = await _post('/api/v1/db/genres', {});
    return {
      for (final e in (res['genres'] as List? ?? const []))
        if (e is Map && e['name'] is String)
          e['name'] as String: (e['track_count'] as num?)?.toInt() ?? 0,
    };
  }

  /// Every playlist with its tracks: `getall` names them, `load` lists
  /// each. Paths get the leading slash the manifest uses.
  @override
  Future<List<PlaylistRow>> playlists() async {
    final names = await _get('/api/v1/playlist/getall');
    final out = <PlaylistRow>[];
    for (final e in (names as List? ?? const [])) {
      final name = e is Map ? e['name'] : null;
      if (name is! String) continue;
      final items =
          await _post('/api/v1/playlist/load', {'playlistname': name});
      out.add(PlaylistRow(id: name, name: name, paths: [
        for (final t in (items as List? ?? const []))
          if (t is Map && t['filepath'] is String)
            _dataPath(t['filepath'] as String),
      ]));
    }
    return out;
  }

  @override
  Future<Map<String, int>> rated() async {
    final res = await _get('/api/v1/db/rated');
    return {
      for (final e in (res as List? ?? const []))
        if (e is Map &&
            e['filepath'] is String &&
            (e['metadata'] as Map?)?['rating'] is num)
          _dataPath(e['filepath'] as String):
              ((e['metadata'] as Map)['rating'] as num).toInt(),
    };
  }

  @override
  Future<List<AlbumRow>> albums() async {
    final res = await _get('/api/v1/db/albums');
    return [
      for (final e in (res['albums'] as List? ?? const []))
        if (e is Map && e['name'] is String)
          AlbumRow(
            name: e['name'] as String,
            albumArtist:
                (e['album_artist'] ?? e['albumArtist'] ?? e['artist'])?.toString(),
            year: (e['year'] as num?)?.toInt(),
            art: e['album_art_file'] as String?,
          ),
    ];
  }

  @override
  Future<List<String>> artists() async {
    final res = await _get('/api/v1/db/artists');
    return [
      for (final e in (res['artists'] as List? ?? const []))
        if (e is String) e else if (e is Map && e['name'] is String) e['name'] as String,
    ];
  }
}

/// One album-art file at the medium size the list rows use, straight to the
/// runner's temp path.
class ServerArtClient implements ArtClient {
  final Server server;
  final http.Client Function() _newClient;

  ServerArtClient(this.server, {http.Client Function()? client})
      : _newClient = client ?? http.Client.new;

  @override
  Future<void> fetchArt(String artFile, String destination) async {
    final client = _newClient();
    try {
      final res = await client
          .get(Uri.parse(buildAlbumArtUrl(server, artFile, compress: 'm')))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('album-art/$artFile: HTTP ${res.statusCode}');
      }
      await File(destination).writeAsBytes(res.bodyBytes, flush: true);
    } finally {
      client.close();
    }
  }
}

/// The engine's [Downloader] over background_downloader: one task per file
/// in the mirror group, resumable, retried, Wi-Fi-gated on request, landing
/// exactly where the runner asked (its temp tree).
class _MirrorDownloader implements Downloader {
  final Server server;
  final MirrorManager manager;
  _MirrorDownloader(this.server, this.manager);

  @override
  Future<void> download(String path, String destination,
      {bool requiresWiFi = false}) async {
    final task = DownloadTask(
      url: buildServerDownloadUrl(server, path),
      filename: p.basename(destination),
      baseDirectory: BaseDirectory.root,
      directory: p.dirname(destination),
      group: kMirrorGroup,
      updates: Updates.status,
      retries: 5,
      allowPause: true,
      requiresWiFi: requiresWiFi,
      // Below the default (5): a running mirror must not starve a track the
      // user just asked for.
      priority: 8,
    );
    final done = Completer<void>();
    manager._tasks[task.taskId] = done;
    try {
      if (!await FileDownloader().enqueue(task)) {
        throw StateError('download task rejected');
      }
      await done.future;
    } finally {
      manager._tasks.remove(task.taskId);
    }
  }
}
