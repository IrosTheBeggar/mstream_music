/// One track kept on disk by the keep-queue-offline auto-downloader, tracked so
/// the cap can evict the oldest when the total grows past the user's limit.
///
/// Separate from user-initiated downloads ON PURPOSE: eviction must never touch
/// a file the user asked for explicitly. A manual download of the same track
/// removes it from the ledger (manual wins permanently), and downloads that
/// predate this feature are never recorded — so they're grandfathered as
/// manual and can't be evicted.
class AutoDownloadEntry {
  final String server; // server localname
  final String path; // data path on that server
  final String localPath; // absolute file on disk

  AutoDownloadEntry(this.server, this.path, this.localPath);

  String get key => server + path;

  Map<String, dynamic> toJson() =>
      {'server': server, 'path': path, 'localPath': localPath};

  static AutoDownloadEntry? fromJson(Map<String, dynamic> j) {
    final s = j['server'], p = j['path'], lp = j['localPath'];
    if (s is! String || p is! String || lp is! String) return null;
    return AutoDownloadEntry(s, p, lp);
  }
}
