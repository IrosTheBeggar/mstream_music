import 'dart:async';
import 'dart:io';

import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/app_messenger.dart';
import 'package:mstream_music/singletons/migration_manager.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:rxdart/rxdart.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as path;

import '../objects/download_tracker.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

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

  Future<void> initDownloader() async {
    // background_downloader delivers status + progress for every task on a
    // single stream, so the old flutter_downloader background-isolate /
    // SendPort plumbing is no longer needed.
    _updatesSub = FileDownloader().updates.listen(_onUpdate);
  }

  void _onUpdate(TaskUpdate update) {
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
          // TODO: patch matching queue MediaItems' localPath so an
          // already-queued track switches from streaming to the fresh
          // local copy without a queue rebuild.
          break;
        case TaskStatus.failed:
        case TaskStatus.notFound:
          // Reset the row so a stuck partial bar doesn't imply a cached
          // file that isn't there, and tell the user it didn't work.
          dt.progress = 0;
          terminal = true;
          final ctx = rootMessengerKey.currentContext;
          showGlobalSnack(ctx != null
              ? AppLocalizations.of(ctx).dlFailed
              : 'A download failed — check your connection.');
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
        BrowserManager().updateStream();
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

  disposeDownloader() {}

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

  Future<void> downloadOneFile(String downloadUrl, String serverName,
      String filepath,
      {DisplayItem? referenceItem}) async {
    String downloadDirectory = serverName + filepath;

    // The originating server may have been removed while this track lingered
    // in the queue — lookupServer is a bare firstWhere that would throw.
    final Server server;
    try {
      server = ServerManager().lookupServer(serverName);
    } catch (_) {
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
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null
          ? AppLocalizations.of(ctx).dlStorageUnavailable
          : 'Storage location unavailable — reconnect the SD card or change '
              "this server's storage location in Edit Server.");
      return;
    }

    // A user-chosen folder (Permanent / SD card) may sit on a FAT/exFAT
    // filesystem that can't store certain names. When the name is illegal,
    // probe the actual destination (cached) — the same source of truth
    // migration uses, rather than trusting the mode label — and skip it
    // (it would fail to write anyway), warning once.
    final isUserFolder =
        server.storageMode == 'permanent' || server.storageMode == 'sdCard';
    if (isUserFolder &&
        hasFatIllegalChars(downloadDirectory) &&
        await isFatLikeDir(dir.path)) {
      _warnFatSkip();
      return;
    }

    String downloadTo = '${dir.path}/media/$downloadDirectory';

    if (new File(downloadTo).existsSync() == true) {
      return; // already cached on disk
    }
    if (_inFlight.contains(downloadDirectory)) {
      return; // a download for this exact file is already running
    }

    String targetDir = path.dirname(downloadTo);
    String filename = path.basename(downloadTo);

    try {
      new Directory(targetDir).createSync(recursive: true);

      // The destination is an absolute path (app docs, a permanent shared
      // folder, or the SD card), expressed to background_downloader via
      // BaseDirectory.root + the absolute directory.
      final DownloadTask task = DownloadTask(
        url: downloadUrl,
        filename: filename,
        baseDirectory: BaseDirectory.root,
        directory: targetDir,
        updates: Updates.statusAndProgress,
      );

      _inFlight.add(downloadDirectory);
      downloadMap[task.taskId] =
          new DownloadTracker(downloadUrl, downloadDirectory)
            ..referenceDisplayItem = referenceItem;
      _downloadStream.add(downloadMap);

      await FileDownloader().enqueue(task);
    } catch (e) {
      // The volume could vanish between the null-check and the write.
      _inFlight.remove(downloadDirectory);
      final ctx = rootMessengerKey.currentContext;
      showGlobalSnack(ctx != null
          ? AppLocalizations.of(ctx).dlCouldNotStart
          : 'Could not start download — storage unavailable.');
    }
  }

  Stream<Map<String, DownloadTracker>> get downloadSream =>
      _downloadStream.stream;
}
