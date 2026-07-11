import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/app_messenger.dart';
import 'package:mstream_music/singletons/migration_manager.dart';
import 'package:mstream_music/singletons/log_manager.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/singletons/auto_download_ledger.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:rxdart/rxdart.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as path;

import '../objects/download_tracker.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../media/cast_origin.dart' show irohLoopbackUri;

class DownloadManager {
  DownloadManager._privateConstructor();
  static final DownloadManager _instance =
      DownloadManager._privateConstructor();
  factory DownloadManager() {
    return _instance;
  }

  // streams
  late final BehaviorSubject<Map<String, DownloadTracker>> _downloadStream =
      BehaviorSubject<Map<String, DownloadTracker>>.seeded(downloadMap);

  Map<String, DownloadTracker> downloadMap = {};
  // Destination keys (serverName+filepath) of downloads currently in
  // flight, so a duplicate tap / second "Download all" can't enqueue the
  // same file twice and interleave writes to the same path.
  final Set<String> _inFlight = {};
  // Throttle the "unsupported name" warning so a "Download all" to an SD card
  // doesn't queue one snackbar per skipped file.
  DateTime? _lastFatWarn;
  StreamSubscription<TaskUpdate>? _updatesSub;
  // Cap on how many times a single download is re-resolved onto a fresh iroh
  // tunnel URL after a hard rebuild, so a repeatedly-rotating tunnel can't loop.
  static const int _kMaxReResolves = 2;
  // Files the keep-queue-offline sweep has already enqueued once this session
  // (keyed serverName+filepath), so a failing source can't re-enqueue on every
  // queue emission. Manual downloads bypass this — user-driven retries stay
  // possible — and flipping the setting ON clears it (sweepQueueNow).
  final Set<String> _autoAttempted = {};

  Future<void> initDownloader() async {
    // background_downloader delivers status + progress for every task on a
    // single stream, so the old flutter_downloader background-isolate /
    // SendPort plumbing is no longer needed.
    _updatesSub = FileDownloader().updates.listen(_onUpdate);
    // Load the auto-download ledger before any sweep records into it.
    await AutoDownloadLedger().load();
    // Rehydrate tasks that survived a process death in WorkManager (a
    // Wi-Fi-held keep-queue-offline transfer routinely does). Without this a
    // relaunch sweep re-enqueues DUPLICATES of every held task — the guards
    // below are in-memory only — and the survivors' completions would be
    // dropped (no tracker → no queue patch, downloads invisible on the
    // Downloads screen).
    try {
      for (final t in await FileDownloader().allTasks()) {
        if (t is! DownloadTask) continue;
        // downloadTo is '<base>/media/<serverName><filepath>' — recover the
        // dedupe key (serverName+filepath) from the path under /media/.
        final marker = t.directory.indexOf('/media/');
        if (marker < 0) continue;
        final key = '${t.directory.substring(marker + 7)}/${t.filename}';
        final slash = key.indexOf('/');
        if (slash <= 0) continue;
        _inFlight.add(key);
        _autoAttempted.add(key);
        downloadMap[t.taskId] = DownloadTracker(t.url, key)
          ..serverName = key.substring(0, slash)
          ..dataPath = key.substring(slash)
          ..localPath = '${t.directory}/${t.filename}'
          ..requiresWiFi = t.requiresWiFi
          // A Wi-Fi-held survivor is a keep-queue-offline transfer — manual
          // downloads never set requiresWiFi — so recovering its auto flag from
          // that can't mislabel a user download as evictable.
          ..auto = t.requiresWiFi;
      }
      if (downloadMap.isNotEmpty) _downloadStream.add(downloadMap);
    } catch (e) {
      appLog('[dl] task rehydration failed: $e');
    }
  }

  Future<void> _onUpdate(TaskUpdate update) async {
    final DownloadTracker? dt = downloadMap[update.task.taskId];
    if (dt == null) return;

    bool terminal = false;
    if (update is TaskProgressUpdate) {
      // progress is 0.0–1.0; negative values signal error/special states,
      // so ignore those and keep the last good value.
      if (update.progress >= 0) dt.progress = update.progress;
    } else if (update is TaskStatusUpdate) {
      switch (update.status) {
        case TaskStatus.complete:
          dt.progress = 1.0;
          terminal = true;
          // Flip already-queued copies of this track from streaming to the
          // fresh local file (extras patch + upcoming-source swap; the
          // playing track is never interrupted). Cheap no-op if not queued.
          if (dt.localPath != null &&
              dt.serverName != null &&
              dt.dataPath != null) {
            MediaManager().audioHandler.onTrackDownloaded(
                dt.serverName!, dt.dataPath!, dt.localPath!);
            // Record auto-downloads in the ledger and enforce the cap. Only
            // here (a fresh auto-download landing, i.e. online) — never on
            // startup or a connectivity change, so waking up offline can't
            // trigger a sweep that deletes what you're about to play.
            if (dt.auto) {
              await AutoDownloadLedger()
                  .record(dt.serverName!, dt.dataPath!, dt.localPath!);
              await _enforceAutoDownloadCap();
            }
          }
          break;
        case TaskStatus.failed:
          // An iroh download's URL bakes in the loopback port + __lt token, and a
          // hard tunnel rebuild rotates both (background_downloader's own retries
          // reuse the same dead URL). Re-resolve against the live tunnel and
          // re-enqueue before giving up — only then is it a genuine failure. The
          // re-enqueued task carries its own tracker, so bail here without a toast.
          if (await _reEnqueueOnLiveTunnel(dt, update.task)) return;
          dt.progress = 0;
          terminal = true;
          _unmarkAutoAttempt(dt);
          _warnDownloadFailed();
          break;
        case TaskStatus.notFound:
          // 404 — the source is genuinely gone; re-resolving wouldn't help.
          dt.progress = 0;
          terminal = true;
          _unmarkAutoAttempt(dt);
          _warnDownloadFailed();
          break;
        case TaskStatus.canceled:
          dt.progress = 0;
          terminal = true;
          break;
        default:
          break; // enqueued / running / paused / waitingToRetry
      }
    }

    // Drive the originating browser row's inline progress bar, if any.
    // Quantize to 5% buckets so a full-list repaint fires at most ~20
    // times per download instead of up to 100× — this matters when
    // "Download all" runs many downloads concurrently. Completion still
    // lands on 100 (a multiple of 5).
    final DisplayItem? row = dt.referenceDisplayItem;
    if (row != null) {
      final int pct = ((dt.progress.clamp(0.0, 1.0) * 100).round() ~/ 5) * 5;
      if (row.downloadProgress != pct) {
        row.downloadProgress = pct;
        BrowserManager().updateStreamCoalesced();
      }
    }

    // On a terminal status, release the tracker (and the DisplayItem it
    // retains) and clear the in-flight guard so the file can be retried.
    if (terminal) {
      _inFlight.remove(dt.filePath);
      dt.referenceDisplayItem = null;
      downloadMap.remove(update.task.taskId);
    }

    // Re-emit so the Downloads screen's StreamBuilder rebuilds.
    _downloadStream.add(downloadMap);
  }

  // A terminally-failed download must not eat the once-per-session sweep
  // guard: the keep-queue-offline retry pressure comes from the NEXT sweep
  // (queue change / connectivity- or tunnel-regained re-sweep), and each
  // attempt already costs background_downloader's full retries:5 backoff —
  // stranding the key until an app restart is what actually hurt.
  void _unmarkAutoAttempt(DownloadTracker dt) {
    final name = dt.serverName;
    final path = dt.dataPath;
    if (name != null && path != null) _autoAttempted.remove(name + path);
  }

  // Throttled like _warnFatSkip: a burst of terminal failures (dead server ×
  // whole-queue sweep) must not queue one snackbar per track — snackbars show
  // sequentially for ~4s each, so an unthrottled burst toasts for minutes.
  DateTime? _lastFailWarn;
  void _warnDownloadFailed() {
    final now = DateTime.now();
    if (_lastFailWarn != null &&
        now.difference(_lastFailWarn!) < const Duration(seconds: 3)) {
      return;
    }
    _lastFailWarn = now;
    final ctx = rootMessengerKey.currentContext;
    // Reset the row (handled by the caller) and tell the user it didn't work.
    showGlobalSnack(ctx != null
        ? AppLocalizations.of(ctx).dlFailed
        : 'A download failed — check your connection.');
  }

  // A failed iroh download may just have a stale loopback URL: the captured
  // http://127.0.0.1:<port>/...&__lt=<token> is invalidated by a hard tunnel
  // rebuild (server switch / re-pair / verify-when-down), and
  // background_downloader's retries reuse it. Bring the tunnel back up, re-origin
  // the URL onto the live port + token, and re-enqueue under a fresh task.
  // Returns true when it re-enqueued (the caller treats the failure as
  // non-terminal). Bounded by [_kMaxReResolves]; only fires when the URL actually
  // changed, so a genuinely dead source or an unchanged tunnel still fails.
  Future<bool> _reEnqueueOnLiveTunnel(DownloadTracker dt, Task failed) async {
    final name = dt.serverName;
    final dataPath = dt.dataPath;
    if (name == null || dataPath == null) return false;
    if (dt.reResolves >= _kMaxReResolves) return false;

    final Server server;
    try {
      server = ServerManager().lookupServer(name);
    } catch (_) {
      return false; // server removed while the download lingered
    }
    if (!server.isIroh) return false; // only loopback URLs rotate this way

    // Bring the tunnel up (rebuilds it if hard-down) and wait for a live port;
    // if it can't connect, this is a real failure.
    if (!await ServerManager().awaitTunnelReady(server: server)) return false;
    final freshUrl = irohLoopbackUri(server, dt.serverUrl).toString();
    if (freshUrl == dt.serverUrl) return false; // port + token didn't rotate

    // Hand off to a fresh task: drop this one's bookkeeping so the re-enqueue's
    // existence / in-flight guards pass, then go through the normal enqueue path
    // (re-resolves the destination dir, applies retries) carrying the bumped count.
    downloadMap.remove(failed.taskId);
    _inFlight.remove(dt.filePath);
    await downloadOneFile(freshUrl, name, dataPath,
        referenceItem: dt.referenceDisplayItem,
        reResolves: dt.reResolves + 1,
        requiresWiFi: dt.requiresWiFi,
        auto: dt.auto, // keep it evictable across a tunnel re-resolve

        // This path already avoids toasts (see caller); a re-enqueue that
        // ultimately fails lands in the throttled terminal-failure warn.
        quiet: true);
    return true;
  }

  void disposeDownloader() {}

  void dispose() {
    _updatesSub?.cancel();
    _downloadStream.close();
  }

  // Cancel every in-flight download. Used before a storage-location change so
  // nothing lands at the old location after the switch (it would be stranded).
  // The canceled-task updates flow through _onUpdate, which resets each row and
  // removes its tracker.
  Future<void> cancelAll() async {
    try {
      final tasks = await FileDownloader().allTasks();
      if (tasks.isNotEmpty) {
        await FileDownloader()
            .cancelTasksWithIds(tasks.map((t) => t.taskId).toList());
      }
    } catch (_) {}
    _inFlight.clear(); // allow immediate re-download of the same files
  }

  // Show the "name not supported" warning, at most once every few seconds so
  // a batch download doesn't queue a snackbar per skipped file.
  void _warnFatSkip() {
    final now = DateTime.now();
    if (_lastFatWarn == null ||
        now.difference(_lastFatWarn!) > const Duration(seconds: 3)) {
      _lastFatWarn = now;
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null
          ? AppLocalizations.of(ctx).dlFatSkip
          : "Some tracks can't be saved on this card — their names aren't "
              'supported. They stream instead.');
    }
  }

  /// Re-attach in-flight downloads to a freshly-built list of browser rows.
  ///
  /// When a directory is re-fetched (e.g. navigating out and back in), its
  /// DisplayItems are NEW instances starting at 0 progress, while the active
  /// download still points at the discarded original row — so its inline bar
  /// vanishes. For each row matching an in-flight tracker (by serverName +
  /// filepath), seed the row's progress and re-point the tracker at it so
  /// subsequent ticks drive the row the user is actually looking at. Cheap
  /// no-op when nothing is downloading. (Same 5% quantization as _onUpdate.)
  void rebindActiveDownloads(Iterable<DisplayItem> rows) {
    if (downloadMap.isEmpty) return;
    final byPath = <String, DownloadTracker>{
      for (final t in downloadMap.values) t.filePath: t,
    };
    for (final r in rows) {
      if (r.type != 'file' || r.server == null || r.data == null) continue;
      final t = byPath[r.server!.localname + r.data!];
      if (t == null) continue;
      r.downloadProgress = ((t.progress.clamp(0.0, 1.0) * 100).round() ~/ 5) * 5;
      t.referenceDisplayItem = r;
    }
  }

  /// The queued items the offline sweep should enqueue: server tracks whose
  /// file isn't on disk and that weren't attempted before (marks them in
  /// [attempted], so repeat sweeps and same-track duplicates are skipped).
  /// [fileExists] probes a localPath — a queued copy whose downloaded file
  /// was deleted (folder cleaned, SD ejected) carries a DEAD localPath and
  /// must be a candidate again, mirroring how every playback consumer of
  /// localPath probes before using it. Pure over the inputs; unit-tested.
  static List<MediaItem> autoDownloadCandidates(
      List<MediaItem> items, Set<String> attempted,
      {required bool Function(String path) fileExists}) {
    final out = <MediaItem>[];
    for (final m in items) {
      final server = m.extras?['server'] as String?;
      final path = m.extras?['path'] as String?;
      if (server == null || path == null) continue;
      final localPath = m.extras?['localPath'] as String?;
      if (localPath != null && fileExists(localPath)) continue;
      if (!attempted.add(server + path)) continue;
      out.add(m);
    }
    return out;
  }

  /// Keep-queue-offline sweep: enqueue a download for every queued server
  /// track not yet on disk. Fired on every queue change (audio_stuff._init)
  /// and on connectivity/tunnel recovery, and cheap when there's nothing to
  /// do — completed tracks carry localPath (patched on completion), in-flight
  /// ones are deduped by [_inFlight], and each file is attempted once per
  /// session (terminal failures un-mark themselves so a recovery re-sweep
  /// retries them). Quiet: no per-file snackbars — the user didn't tap
  /// anything, and a whole-queue sweep can fail dozens of times at once.
  Future<void> autoDownloadQueue(List<MediaItem> items) async {
    if (!SettingsManager().offlineQueue) return;
    final wifiOnly = SettingsManager().offlineQueueWifiOnly;
    for (final m in autoDownloadCandidates(items, _autoAttempted,
        fileExists: (p) => File(p).existsSync())) {
      await downloadOneFile(m.id, m.extras!['server'], m.extras!['path'],
          requiresWiFi: wifiOnly, auto: true, quiet: true);
    }
  }

  /// Delete auto-downloads over the user's cap, oldest orphans first. Runs
  /// after a fresh auto-download lands and when the user lowers the cap — both
  /// deliberate, online-ish moments; never from startup or a connectivity
  /// change. Tracks still in the queue (incl. the playing one) are protected,
  /// so the queue stays fully offline-available and only the extra cache is
  /// trimmed. cap 0 = keep everything.
  Future<void> enforceAutoDownloadCap() => _enforceAutoDownloadCap();

  Future<void> _enforceAutoDownloadCap() async {
    final cap = SettingsManager().autoDownloadCap;
    if (cap <= 0) return;
    // Protected = anything in the current queue, keyed serverName+path (the
    // same key the ledger and the queue's extras share).
    final queued = <String>{};
    for (final m in MediaManager().audioHandler.queue.value) {
      final s = m.extras?['server'], p = m.extras?['path'];
      if (s is String && p is String) queued.add(s + p);
    }
    final victims =
        AutoDownloadLedger().evictionsFor(cap, (s, p) => queued.contains(s + p));
    if (victims.isEmpty) return;
    for (final v in victims) {
      try {
        final f = File(v.localPath);
        if (f.existsSync()) f.deleteSync();
      } catch (e) {
        appLog('[auto-dl] evict delete failed: $e');
      }
      // Drop the once-per-session sweep guard so the track can auto-download
      // again if it later re-enters the queue, and drop it from the ledger.
      _autoAttempted.remove(v.key);
      await AutoDownloadLedger().forget(v.server, v.path);
    }
    appLog('[auto-dl] evicted ${victims.length} over cap $cap');
    // The "downloaded" badge is file-existence derived; refresh any visible
    // rows so a deleted orphan stops claiming a local copy. Evicted tracks are
    // never in the queue, so no queue source needs reversing.
    unawaited(BrowserManager().refreshAllDownloadStatus());
  }

  /// Re-sweep the current queue immediately — used when the user flips the
  /// keep-queue-offline setting ON, so it acts now instead of on the next
  /// queue edit. Clears the once-per-session guard so earlier failures get a
  /// fresh chance.
  Future<void> sweepQueueNow() async {
    _autoAttempted.clear();
    await autoDownloadQueue(MediaManager().audioHandler.queue.value);
  }

  /// Cancel keep-queue-offline transfers still waiting on Wi-Fi. Called when
  /// the setting turns OFF: those tasks would otherwise sit held in
  /// WorkManager indefinitely (surviving restarts) and fire long after the
  /// user said stop. Already-running transfers finish — they still patch the
  /// queue on completion, which is what the user asked for when they were
  /// enqueued.
  Future<void> cancelWifiHeld() async {
    final ids = [
      for (final e in downloadMap.entries)
        if (e.value.requiresWiFi) e.key,
    ];
    if (ids.isEmpty) return;
    try {
      await FileDownloader().cancelTasksWithIds(ids);
    } catch (e) {
      appLog('[dl] cancel of Wi-Fi-held tasks failed: $e');
    }
  }

  Future<void> downloadOneFile(String downloadUrl, String serverName,
      String filepath,
      {DisplayItem? referenceItem,
      int reResolves = 0,
      bool requiresWiFi = false,
      // The keep-queue-offline sweep passes true: the download is tracked in
      // the ledger and eligible for cap eviction. A user-initiated download
      // (false) instead FORGETS the track from the ledger — an explicit
      // download promotes it to manual permanently, so the cap never deletes it.
      bool auto = false,
      // Suppress the per-call snackbars — the keep-queue-offline sweep passes
      // true (nothing user-initiated, and a whole-queue sweep can hit the
      // same error dozens of times); manual downloads keep their feedback.
      bool quiet = false}) async {
    String downloadDirectory = serverName + filepath;

    // Manual wins: an explicit download of a track removes it from the auto
    // ledger so it can never be evicted (forget is a cheap no-op when it isn't
    // tracked). Done up front so it applies whether or not the file already
    // exists below. Also demote any in-flight auto-download of the same track,
    // so when it completes it records as manual (i.e. isn't re-added to the
    // ledger) instead of racing the forget.
    if (!auto) {
      unawaited(AutoDownloadLedger().forget(serverName, filepath));
      for (final t in downloadMap.values) {
        if (t.serverName == serverName && t.dataPath == filepath) {
          t.auto = false;
        }
      }
    }

    // The originating server may have been removed while this track lingered
    // in the queue — lookupServer is a bare firstWhere that would throw.
    final Server server;
    try {
      server = ServerManager().lookupServer(serverName);
    } catch (_) {
      if (quiet) return;
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null
          ? AppLocalizations.of(ctx).dlServerGone
          : 'That server is no longer configured.');
      return;
    }

    final dir = await FileExplorer()
        .getDownloadDir(server.storageMode, server.storageBasePath);
    if (dir == null) {
      // Storage location unavailable (e.g. SD card removed / chosen folder
      // deleted). Tell the user instead of silently doing nothing.
      if (quiet) return;
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null && ctx.mounted
          ? AppLocalizations.of(ctx).dlStorageUnavailable
          : 'Storage location unavailable — reconnect the SD card or change '
              "this server's storage location in Edit Server.");
      return;
    }

    // Any destination that can sit on a FAT/exFAT volume — the SD card
    // (sdCardApp) or a user-chosen Permanent/SD folder — may be unable to store
    // certain names. The name check is cheap; only when it trips do we probe the
    // actual destination filesystem (cached — the same source of truth migration
    // uses, rather than trusting the mode label) and skip the file (it would fail
    // to write anyway), warning once. Internal storage (ext4/f2fs) never trips
    // isFatLikeDir, so this is a no-op there.
    if (hasFatIllegalChars(downloadDirectory) && await isFatLikeDir(dir.path)) {
      _warnFatSkip();
      return;
    }

    String downloadTo = '${dir.path}/media/$downloadDirectory';

    if (File(downloadTo).existsSync() == true) {
      // Already on disk — still patch any queued copies (self-healing: covers
      // a track downloaded before it was queued, and a patch lost to a rare
      // publish race — every later download attempt re-lands it).
      MediaManager()
          .audioHandler
          .onTrackDownloaded(serverName, filepath, downloadTo);
      return;
    }
    if (_inFlight.contains(downloadDirectory)) {
      return; // a download for this exact file is already running
    }

    String targetDir = path.dirname(downloadTo);
    String filename = path.basename(downloadTo);

    try {
      Directory(targetDir).createSync(recursive: true);

      // The destination is an absolute path (app docs, a permanent shared
      // folder, or the SD card), expressed to background_downloader via
      // BaseDirectory.root + the absolute directory.
      final DownloadTask task = DownloadTask(
        url: downloadUrl,
        filename: filename,
        baseDirectory: BaseDirectory.root,
        directory: targetDir,
        updates: Updates.statusAndProgress,
        // Survive a transient network interruption (Wi-Fi blip, Wi-Fi<->cellular
        // handover). Without this, background_downloader defaults to retries: 0,
        // so the moment the network drops WorkManager cancels the in-flight
        // worker and the download fails permanently instead of resuming when the
        // network returns. Retries back off exponentially and only surface a
        // terminal `failed` once exhausted; the intermediate `waitingToRetry`
        // status is already treated as non-terminal in _onUpdate.
        retries: 5,
        // Keep-queue-offline honors its Wi-Fi-only setting: the OS holds the
        // transfer until Wi-Fi is available instead of failing it.
        requiresWiFi: requiresWiFi,
      );

      _inFlight.add(downloadDirectory);
      downloadMap[task.taskId] =
          DownloadTracker(downloadUrl, downloadDirectory)
            ..referenceDisplayItem = referenceItem
            ..serverName = serverName
            ..dataPath = filepath
            ..localPath = downloadTo
            ..requiresWiFi = requiresWiFi
            ..reResolves = reResolves
            ..auto = auto;
      _downloadStream.add(downloadMap);

      await FileDownloader().enqueue(task);
    } catch (e) {
      // The volume could vanish between the null-check and the write.
      _inFlight.remove(downloadDirectory);
      if (quiet) return;
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null && ctx.mounted
          ? AppLocalizations.of(ctx).dlCouldNotStart
          : 'Could not start download — storage unavailable.');
    }
  }

  Stream<Map<String, DownloadTracker>> get downloadSream =>
      _downloadStream.stream;
}
