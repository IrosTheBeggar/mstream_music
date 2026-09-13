/// One track kept on disk by the keep-queue-offline auto-downloader, as the
/// cap's eviction pass sees it: since A8 a view over the library index's
/// `auto` rows, oldest first. The JSON shape is the pre-A8 ledger file
/// (`auto_downloads.json`), read once by the migration.
///
/// Separate from user-initiated downloads ON PURPOSE: eviction must never touch
/// a file the user asked for explicitly. A manual download of the same track
/// re-labels it `manual` (manual wins permanently), and downloads that
/// predate this feature were imported as manual — so they can't be evicted.
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
