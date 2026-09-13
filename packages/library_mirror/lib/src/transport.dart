import 'models.dart';

/// One page of `POST /api/v1/sync/manifest` (mStream #984).
class ManifestPage {
  final String revision;
  final bool scanning;
  final int? next;
  final List<RemoteTrack> entries;

  const ManifestPage({
    required this.revision,
    required this.scanning,
    required this.next,
    required this.entries,
  });

  factory ManifestPage.fromJson(Map<String, dynamic> j) => ManifestPage(
        revision: j['revision'] as String,
        scanning: j['scanning'] == true,
        next: (j['next'] as num?)?.toInt(),
        entries: [
          for (final e in (j['entries'] as List? ?? const []))
            RemoteTrack.fromManifestEntry((e as Map).cast<String, dynamic>()),
        ],
      );
}

/// Fetches manifest pages. Returns null for a 304 — only possible on the
/// first page, when [ifNoneMatch] carried the revision the server still has.
abstract class ManifestClient {
  Future<ManifestPage?> fetchPage(
      {int? cursor, int limit = 2000, String? ifNoneMatch});
}

/// Moves one server file to [destination] (a temp path the runner owns) and
/// completes once every byte is on disk; throws on failure. The app backs
/// this with background_downloader, tests and the CLI with plain I/O.
abstract class Downloader {
  Future<void> download(String path, String destination,
      {bool requiresWiFi = false});
}

/// The two small whole-library lists the offline browser needs beside the
/// manifest: `db/albums` and `db/artists`, keyed by name like the API.
abstract class LibraryListsClient {
  Future<List<AlbumRow>> albums();
  Future<List<String>> artists();
}

/// Fetches one album-art file (its content-addressed name on the server) to
/// [destination], a temp path the runner owns.
abstract class ArtClient {
  Future<void> fetchArt(String artFile, String destination);
}
