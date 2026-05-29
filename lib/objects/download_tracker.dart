import 'display_item.dart';

class DownloadTracker {
  String serverUrl;
  String filePath;

  // 0.0–1.0 (background_downloader progress scale).
  double progress = 0.0;

  // These can be set to update downlaod progress for a particular item
  // you should always check if these exist before using them
  late DisplayItem? referenceDisplayItem;

  DownloadTracker(this.serverUrl, this.filePath);
}
