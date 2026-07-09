import 'display_item.dart';

class DownloadTracker {
  String serverUrl;
  String filePath;

  // 0.0–1.0 (background_downloader progress scale).
  double progress = 0.0;

  // Optional back-reference to the browser row that kicked off this
  // download, so progress updates can drive that row's inline bar. Null
  // for downloads with no on-screen row (e.g. the queue's Sync action).
  DisplayItem? referenceDisplayItem;

  // Originating server localname + data path, kept so a failed iroh download can
  // be re-resolved against the live tunnel and re-enqueued (see DownloadManager).
  String? serverName;
  String? dataPath;
  // Absolute destination file, captured at enqueue (re-deriving it at
  // completion could race a storage-location change). On completion this is
  // what queued copies of the track get patched to play from.
  String? localPath;
  // Wi-Fi-only constraint of the original task, carried so an iroh re-enqueue
  // (fresh task) keeps honoring the keep-queue-offline setting.
  bool requiresWiFi = false;
  // Times this download has been re-resolved onto a fresh iroh tunnel URL; bounds
  // the re-enqueue so a repeatedly-rotating tunnel / dead source can't loop.
  int reResolves = 0;

  DownloadTracker(this.serverUrl, this.filePath);
}
