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

  DownloadTracker(this.serverUrl, this.filePath);
}
