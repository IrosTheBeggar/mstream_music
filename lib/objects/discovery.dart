import 'metadata.dart';

/// Models for the server's discovery (sonic-similarity) API
/// (`/api/v1/discovery/...`). All queries are seed-based — similarity to a
/// given track or artist — and every parser here is defensive about wire
/// shapes, mirroring [MusicMetadata.fromServerMap]: a malformed row is
/// dropped rather than thrown on.
///
/// `genreTags` throughout are the embedding MODEL's style predictions in
/// `"Electronic---Synthwave"` hierarchy form — deliberately a different
/// source from `metadata.genres` (the file's tags).

/// Outcome of one discovery fetch. Three states the UI treats differently:
///   data != null       — parsed payload (possibly with empty results)
///   disabled == true   — HTTP 403: the feature is off on the server → hide
///                        that section for the rest of the session
///   both null/false    — transient failure → skip this refresh quietly
class DiscoveryFetchResult<T> {
  final T? data;
  final bool disabled;

  const DiscoveryFetchResult.ok(this.data) : disabled = false;
  const DiscoveryFetchResult.disabled()
      : data = null,
        disabled = true;
  const DiscoveryFetchResult.error()
      : data = null,
        disabled = false;
}

/// One playable similar-track row (local results and artist entry points).
/// [filepath] is the server's vpath-form path WITHOUT a leading slash; add
/// one when building a DisplayItem (`'/<filepath>'`), matching every other
/// browse fetch.
class DiscoveryTrack {
  final String filepath;
  final double similarity; // 0..1; 0 for entry points (server omits it there)
  final MusicMetadata? metadata;
  final List<String> genreTags;

  DiscoveryTrack(this.filepath, this.similarity, this.metadata, this.genreTags);

  static DiscoveryTrack? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final fp = m['filepath'];
    if (fp is! String || fp.isEmpty) return null;
    final md = m['metadata'];
    return DiscoveryTrack(
      fp,
      _asSimilarity(m['similarity']),
      md is Map ? MusicMetadata.fromServerMap(md) : null,
      parseGenreTags(m['genreTags']),
    );
  }

  String get displayTitle =>
      metadata?.title ?? filepath.split('/').last;
}

/// `POST /api/v1/discovery/local/similar/tracks` response.
class DiscoverySimilarTracks {
  /// True when the seed track exists but hasn't been embedded yet (scan /
  /// backfill still running) — a transient state, not an error.
  final bool notAnalyzed;
  final List<DiscoveryTrack> results;

  DiscoverySimilarTracks(this.notAnalyzed, this.results);

  factory DiscoverySimilarTracks.fromServerMap(Map m) {
    final raw = m['results'];
    return DiscoverySimilarTracks(
      m['notAnalyzed'] == true,
      raw is List
          ? raw
              .map(DiscoveryTrack.fromServerMap)
              .whereType<DiscoveryTrack>()
              .toList()
          : const [],
    );
  }
}

/// One similar-artist match with up to two playable [entryPoints].
class DiscoveryArtistMatch {
  final String artist;
  final double similarity;
  final List<String> genreTags;
  final List<DiscoveryTrack> entryPoints;

  DiscoveryArtistMatch(
      this.artist, this.similarity, this.genreTags, this.entryPoints);

  static DiscoveryArtistMatch? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final artist = m['artist'];
    if (artist is! String || artist.isEmpty) return null;
    final eps = m['entryPoints'];
    return DiscoveryArtistMatch(
      artist,
      _asSimilarity(m['similarity']),
      parseGenreTags(m['genreTags']),
      eps is List
          ? eps
              .map(DiscoveryTrack.fromServerMap)
              .whereType<DiscoveryTrack>()
              .toList()
          : const [],
    );
  }
}

/// `POST /api/v1/discovery/local/similar/artists` response.
class DiscoverySimilarArtists {
  final bool notAnalyzed;
  final List<DiscoveryArtistMatch> results;

  DiscoverySimilarArtists(this.notAnalyzed, this.results);

  factory DiscoverySimilarArtists.fromServerMap(Map m) {
    final raw = m['results'];
    return DiscoverySimilarArtists(
      m['notAnalyzed'] == true,
      raw is List
          ? raw
              .map(DiscoveryArtistMatch.fromServerMap)
              .whereType<DiscoveryArtistMatch>()
              .toList()
          : const [],
    );
  }
}

/// One metadata-only lead from P2P ("From the network") or federation
/// ("From your peers"). Not playable in the app: the track lives in someone
/// else's library. Tap copies "Artist – Title"; [recordingMbid] enables a
/// MusicBrainz link-out.
class DiscoveryLead {
  final String artist;
  final String title;
  final double similarity;
  final double? durationSeconds;
  final String? recordingMbid;
  final List<String> genreTags; // federation only; empty on P2P rows
  final String? peerName;

  DiscoveryLead(this.artist, this.title, this.similarity,
      this.durationSeconds, this.recordingMbid, this.genreTags, this.peerName);

  static DiscoveryLead? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final artist = m['artist'];
    final title = m['title'];
    if (title is! String || title.isEmpty) return null;
    final peer = m['peer'];
    final mbid = m['recordingMbid'];
    final duration = m['duration'];
    return DiscoveryLead(
      artist is String ? artist : '',
      title,
      _asSimilarity(m['similarity']),
      duration is num && duration > 0 ? duration.toDouble() : null,
      mbid is String && mbid.isNotEmpty ? mbid : null,
      parseGenreTags(m['genreTags']),
      peer is Map && peer['name'] is String ? peer['name'] : null,
    );
  }

  /// The clipboard payload ("Artist – Title", or just the title when the
  /// artist is unknown) — same lead-following flow as the webapp.
  String get copyText => artist.isEmpty ? title : '$artist - $title';
}

/// `POST /api/v1/discovery/{p2p,federation}/similar` response. The two routes
/// share the row shape; [unreachablePeers] is only ever non-zero for
/// federation (P2P searches local snapshots, nothing to be unreachable).
class DiscoveryLeads {
  final int searchedPeers;
  final int unreachablePeers;
  final List<DiscoveryLead> results;

  DiscoveryLeads(this.searchedPeers, this.unreachablePeers, this.results);

  factory DiscoveryLeads.fromServerMap(Map m) {
    final searched = m['searched'];
    final raw = m['results'];
    int asCount(dynamic v) => v is num && v > 0 ? v.toInt() : 0;
    return DiscoveryLeads(
      searched is Map ? asCount(searched['peers']) : 0,
      searched is Map ? asCount(searched['unreachable']) : 0,
      raw is List
          ? raw
              .map(DiscoveryLead.fromServerMap)
              .whereType<DiscoveryLead>()
              .toList()
          : const [],
    );
  }
}

/// `POST /api/v1/discovery/local/path` response (mStream #762+): an ordered,
/// playable "journey" from a start track to an end track — seeds included
/// (first and last rows), so [results] queues as-is. Rows reuse the
/// [DiscoveryTrack] shape; the wire's extra `t` (arc position) is implied by
/// list order and not modeled.
class DiscoveryPath {
  /// Per-end "seed exists but isn't embedded yet" — transient, the client
  /// can hint WHICH end is waiting on the discovery worker.
  final bool notAnalyzedStart;
  final bool notAnalyzedEnd;
  final List<DiscoveryTrack> results;

  DiscoveryPath(this.notAnalyzedStart, this.notAnalyzedEnd, this.results);

  factory DiscoveryPath.fromServerMap(Map m) {
    final na = m['notAnalyzed'];
    final raw = m['results'];
    return DiscoveryPath(
      na is Map && na['start'] == true,
      na is Map && na['end'] == true,
      raw is List
          ? raw
              .map(DiscoveryTrack.fromServerMap)
              .whereType<DiscoveryTrack>()
              .toList()
          : const [],
    );
  }

  bool get notAnalyzed => notAnalyzedStart || notAnalyzedEnd;
}

/// Parses a `genreTags` wire value (string list or null) without throwing.
List<String> parseGenreTags(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().where((t) => t.isNotEmpty).toList();
}

/// Display label for model genre tags, matching the webapp: keep the leaf of
/// the `"Parent---Leaf"` hierarchy, at most [max] tags, joined with " · "
/// ("Electronic---Synthwave" → "Synthwave"). Null when there are none.
String? genreTagLabel(List<String> tags, {int max = 2}) {
  if (tags.isEmpty) return null;
  return tags.take(max).map((t) => t.split('---').last).join(' · ');
}

/// Similarity is 0..1 from the server; coerce num-or-string and clamp so a
/// misbehaving peer can't produce a >100% match meter.
double _asSimilarity(dynamic v) {
  double d = 0;
  if (v is num) d = v.toDouble();
  if (v is String) d = double.tryParse(v) ?? 0;
  if (d.isNaN) return 0;
  return d.clamp(0.0, 1.0);
}
