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
  // Times this download has been re-resolved onto a fresh iroh tunnel URL; bounds
  // the re-enqueue so a repeatedly-rotating tunnel / dead source can't loop.
  int reResolves = 0;

  DownloadTracker(this.serverUrl, this.filePath);
}
