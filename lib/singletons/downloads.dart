import 'dart:async';
import 'dart:io';

import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/app_messenger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as path;

import '../objects/download_tracker.dart';
import '../objects/display_item.dart';

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

    if (update is TaskProgressUpdate) {
      // progress is 0.0–1.0; negative values signal error/special states,
      // so ignore those and keep the last good value.
      if (update.progress >= 0) dt.progress = update.progress;
    } else if (update is TaskStatusUpdate) {
      if (update.status == TaskStatus.complete) {
        dt.progress = 1.0;
        // TODO: update queue items
      }
    }

    // Drive the originating browser row's inline progress bar, if any.
    // Only repaint the browser when the rounded percentage actually
    // changes, so a burst of sub-percent ticks doesn't thrash the list.
    final DisplayItem? row = dt.referenceDisplayItem;
    if (row != null) {
      final int pct = (dt.progress.clamp(0.0, 1.0) * 100).round();
      if (row.downloadProgress != pct) {
        row.downloadProgress = pct;
        BrowserManager().updateStream();
      }
    }

    // Re-emit so the Downloads screen's StreamBuilder rebuilds.
    _downloadStream.add(downloadMap);
  }

  disposeDownloader() {}

  void dispose() {
    _updatesSub?.cancel();
    _downloadStream.close();
  }

  Future<void> downloadOneFile(String downloadUrl, String serverName,
      String filepath,
      {DisplayItem? referenceItem}) async {
    String downloadDirectory = serverName + filepath;

    final server = ServerManager().lookupServer(serverName);
    final dir = await FileExplorer()
        .getDownloadDir(server.storageMode, server.storageBasePath);
    if (dir == null) {
      // Storage location unavailable (e.g. SD card removed / chosen folder
      // deleted). Tell the user instead of silently doing nothing.
      showGlobalSnack(
          'Storage location unavailable — reconnect the SD card or change '
          "this server's storage location in Edit Server.");
      return;
    }

    String downloadTo = '${dir.path}/media/$downloadDirectory';

    if (new File(downloadTo).existsSync() == true) {
      print('exists!');
      return;
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

      downloadMap[task.taskId] =
          new DownloadTracker(downloadUrl, downloadDirectory)
            ..referenceDisplayItem = referenceItem;
      _downloadStream.add(downloadMap);

      await FileDownloader().enqueue(task);
    } catch (e) {
      // The volume could vanish between the null-check and the write.
      showGlobalSnack('Could not start download — storage unavailable.');
    }
  }

  Stream<Map<String, DownloadTracker>> get downloadSream =>
      _downloadStream.stream;
}
