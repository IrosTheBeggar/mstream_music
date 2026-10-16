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
      _liteMetadata(md),
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
/// ("From your peers"). On the per-song Discover screen it is not playable:
/// the track lives in someone else's library. Tap copies "Artist – Title";
/// [recordingMbid] enables a MusicBrainz link-out.
///
/// The Discover page's rows (`POST /api/v1/discovery/taste`) are the same
/// shape plus provenance the server stamps on them (Discover page plan
/// §2.7): [source]
/// (`p2p` | `federation`), [seedHash] (which seed the row sounds like — p2p
/// only) and, on a federation row, the peer's numeric [peerId] and the
/// PEER's vpath-form [filepath] — what the parent's federation stream proxy
/// plays. [raw] keeps the row exactly as sent: a recommendation is forwarded
/// UNCHANGED to the plug-in resolve / jobs / lookup routes (their schema
/// strips what it does not know), so nothing a later client needs is lost
/// to this parser's view of it.
class DiscoveryLead {
  final String artist;
  final String title;
  final double similarity;
  final double? durationSeconds;
  final String? recordingMbid;
  final List<String> genreTags; // federation only; empty on P2P rows
  final String? peerName;
  final String? album;
  final int? year;
  final String? filepath; // the PEER's path, no leading slash (federation)
  final int? peerId; // the peer's row id on this server (federation)
  final String? source; // 'p2p' | 'federation' (taste rows)
  final String? seedHash; // taste p2p rows only
  final Map<String, dynamic> raw;

  DiscoveryLead(this.artist, this.title, this.similarity,
      this.durationSeconds, this.recordingMbid, this.genreTags, this.peerName,
      {this.album,
      this.year,
      this.filepath,
      this.peerId,
      this.source,
      this.seedHash,
      this.raw = const {}});

  /// [peerId] / [peerName] stand in for a row that does not name its peer
  /// itself — a taste peers row parsed inside its peer's group.
  static DiscoveryLead? fromServerMap(dynamic m,
      {int? peerId, String? peerName}) {
    if (m is! Map) return null;
    final title = _str(m['title']);
    if (title == null) return null;
    final peer = m['peer'];
    final duration = m['duration'];
    return DiscoveryLead(
      _str(m['artist']) ?? '',
      title,
      _asSimilarity(m['similarity']),
      duration is num && duration.isFinite && duration > 0
          ? duration.toDouble()
          : null,
      _str(m['recordingMbid'], max: 64),
      parseGenreTags(m['genreTags']),
      (peer is Map ? _str(peer['name']) : null) ?? peerName,
      album: _str(m['album']),
      year: _int(m['year']),
      filepath: _path(m['filepath']),
      peerId: (peer is Map ? _count(peer['id']) : null) ?? peerId,
      source: _str(m['source'], max: 32),
      seedHash: _hash(m['seedHash']),
      raw: _rawCopy(m),
    );
  }

  /// The clipboard payload ("Artist – Title", or just the title when the
  /// artist is unknown) — same lead-following flow as the webapp.
  String get copyText => artist.isEmpty ? title : '$artist - $title';

  /// A federation row's album-art file on its peer: the row's `albumArt`
  /// (mStream plan §3.1, "Peer covers") — the file name the peer's own
  /// browse rows carry as 'album-art' and its `/album-art/<file>` serves. The
  /// app resolves it against the peer's virtual Server, so the cover is
  /// fetched through the parent's federation art proxy
  /// (`<parent>/api/v1/federation/peers/<id>/art/<file>`, buildAlbumArtUrl).
  /// The other spellings are older guesses, read only after it (as the
  /// webapp's peerArtOf does).
  /// Null for a P2P lead, a peer on an older server (no field), a track
  /// without a cover, or anything but one cached cover's file name (the
  /// proxy takes the file as ONE path segment) — the row keeps the note
  /// tile.
  String? get art {
    for (final k in const ['albumArt', 'art', 'album-art', 'album_art_file']) {
      final v = _artName(raw[k]);
      if (v != null) return v;
    }
    return null;
  }
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

// ─── The Discover page: POST /api/v1/discovery/taste ────────────────────
//
// The history-seeded page (mStream docs/discovery-page-plan.md §3.1–§3.2,
// "the Discover page plan" below). One request answers three sources —
// the user's own library (playable rows + album cards), the P2P network
// (leads) and federated peers (rows the parent's stream proxy plays) —
// seeded by what this account finished or mostly listened to recently.
// Gated on Server.discoveryAvailable && Server.discoveryTasteAvailable
// (flags, never probes); the request carries only keys the route knows (it
// is a new route, so every key is on its Joi floor), and each parser below
// takes what it can from a malformed row rather than throwing.

/// The windows the route accepts, in the bar's order (days; 0 = all time).
/// Anything else is left out of a request, so the server's default (30)
/// applies.
const List<int> kTasteWindows = [7, 30, 90, 0];

/// The window a client asks for until the user picks another (the server's
/// own default too).
const int kTasteDefaultWindow = 30;

/// Route caps (plan §3.1): `pin` ≤ 12 paths (= the seed limit, so a client
/// can pin a whole seed batch — Discover's peers call pins the library
/// answer's seeds), `exclude` ≤ 200 hashes. A request is clamped to them
/// client-side — the route's Joi would 400 the whole call over one extra
/// pin.
const int kTastePinMax = 12;
const int kTasteExcludeMax = 200;

/// The three sources one taste call can ask for. Enum names are the wire
/// values. Clients ask for `peers` in a separate call (plan §3.1) so the
/// library never waits on a 4 s peer deadline — after the library answer
/// lands, pinned to its seeds, so both sections share one seed batch.
enum TasteSource { library, network, peers }

/// Where the seeds came from after the server's widening chain (plan §2.2):
/// a random batch of the window's finished songs, all-time play counters,
/// one random analyzed track (nothing played yet — `fallback`), or only the
/// client's pins.
enum TasteSeedSource {
  history,
  counters,
  random,
  pinned;

  static TasteSeedSource? parse(dynamic v) =>
      v is String ? TasteSeedSource.values.asNameMap()[v] : null;
}

/// Per-source row limits; the server takes seeds 1..12 and tracks 0..50,
/// albums 0..24, network 0..50, peers 0..25 (peers: per peer). Only the set
/// ones are sent.
class TasteLimits {
  final int? seeds;
  final int? tracks;
  final int? albums;
  final int? network;
  final int? peers;

  const TasteLimits(
      {this.seeds, this.tracks, this.albums, this.network, this.peers});

  Map<String, dynamic> toJson() => {
        if (seeds != null) 'seeds': seeds!.clamp(1, 12),
        if (tracks != null) 'tracks': tracks!.clamp(0, 50),
        if (albums != null) 'albums': albums!.clamp(0, 24),
        if (network != null) 'network': network!.clamp(0, 50),
        if (peers != null) 'peers': peers!.clamp(0, 25),
      };
}

/// The body of `POST /api/v1/discovery/taste`. Every key is optional and
/// only the set ones are sent. Nothing is stored between calls: each call
/// is answered from this body alone (plan §2.13, 2026-10-14), so the seeds
/// are a new random batch every time.
class TasteRequest {
  /// Days: 7, 30, 90 or 0 (all time) — see [kTasteWindows].
  final int? window;

  /// Songs to seed from regardless of history (now playing first, songs the
  /// user picked) — this visit only. App-side paths are accepted with their
  /// leading slash; [toJson] strips it, as every discovery route wants.
  final List<String>? pin;

  /// Seed hashes to leave out of THIS call, oldest first (the visit's
  /// drops). The server never stores them.
  final List<String>? exclude;

  /// Which sources to answer; null or empty asks for the server's default
  /// (all three).
  final Set<TasteSource>? sources;
  final TasteLimits? limit;

  /// Client-local pref (SettingsManager.discoverNewArtistsOnly), sent per
  /// call.
  final bool? newArtistsOnly;
  final List<String>? ignoreVPaths;

  const TasteRequest({
    this.window,
    this.pin,
    this.exclude,
    this.sources,
    this.limit,
    this.newArtistsOnly,
    this.ignoreVPaths,
  });

  Map<String, dynamic> toJson() {
    final pins = pin
        ?.map(_stripSlash)
        .where((p) => p.isNotEmpty)
        .take(kTastePinMax)
        .toList();
    final drops = exclude == null ? null : _newestHashes(exclude!);
    final limits = limit?.toJson();
    return {
      if (window != null && kTasteWindows.contains(window)) 'window': window,
      if (pins != null && pins.isNotEmpty) 'pin': pins,
      if (drops != null && drops.isNotEmpty) 'exclude': drops,
      if (sources != null && sources!.isNotEmpty)
        // Canonical order, whatever order the set was built in.
        'sources': [
          for (final s in TasteSource.values)
            if (sources!.contains(s)) s.name
        ],
      if (limits != null && limits.isNotEmpty) 'limit': limits,
      if (newArtistsOnly != null) 'newArtistsOnly': newArtistsOnly,
      if (ignoreVPaths != null && ignoreVPaths!.isNotEmpty)
        'ignoreVPaths': ignoreVPaths,
    };
  }
}

/// One seed the page is built from: a song this account finished
/// ([outcome] `completed`) or mostly listened to (`stopped` past half), a
/// pin, or the random fallback. [filepath] is vpath-form WITHOUT a leading
/// slash; [metadata] is the server's LITE block (rows built from it set
/// partialMetadata).
class TasteSeed {
  final String hash;
  final String filepath;
  final MusicMetadata? metadata;

  /// `completed` | `stopped`; null for a pin, a counters seed or the random
  /// fallback — copy then says neither "finished" nor "listened to".
  final String? outcome;
  final DateTime? lastPlayed;
  final int plays;
  final bool pinned;

  /// False while the seed has no vector yet (scan pending): it is listed but
  /// steers nothing.
  final bool analyzed;

  TasteSeed(this.hash, this.filepath, this.metadata,
      {this.outcome,
      this.lastPlayed,
      this.plays = 0,
      this.pinned = false,
      this.analyzed = true});

  static TasteSeed? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final hash = _hash(m['hash']);
    final fp = _path(m['filepath']);
    if (hash == null || fp == null) return null;
    final outcome = m['outcome'];
    return TasteSeed(
      hash,
      fp,
      _liteMetadata(m['metadata']),
      outcome: outcome == 'completed' || outcome == 'stopped' ? outcome : null,
      lastPlayed: MusicMetadata.utcOrNull(m['lastPlayed']),
      plays: _count(m['plays']) ?? 0,
      pinned: m['pinned'] == true,
      analyzed: m['analyzed'] is bool ? m['analyzed'] as bool : true,
    );
  }

  bool get finished => outcome == 'completed';

  String get displayTitle => metadata?.title ?? filepath.split('/').last;
}

/// One of this call's `exclude` hashes that the server could resolve — what
/// the seeds sheet lists under "dropped" so the user can use it again within
/// the visit.
class TasteExcluded {
  final String hash;
  final String filepath;
  final MusicMetadata? metadata;

  TasteExcluded(this.hash, this.filepath, this.metadata);

  static TasteExcluded? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final hash = _hash(m['hash']);
    final fp = _path(m['filepath']);
    if (hash == null || fp == null) return null;
    return TasteExcluded(hash, fp, _liteMetadata(m['metadata']));
  }

  String get displayTitle => metadata?.title ?? filepath.split('/').last;
}

/// One playable library row. A [DiscoveryTrack] (so the similar-tracks row
/// helpers take it as-is) plus the seed it sounds like and this account's
/// play facts for the "never played" / "last played …" label.
class TasteTrack extends DiscoveryTrack {
  final String? seedHash;

  /// Null when the server did not say (never 0-by-default: "never played" is
  /// a claim).
  final int? playCount;
  final DateTime? lastPlayed;

  TasteTrack(super.filepath, super.similarity, super.metadata, super.genreTags,
      {this.seedHash, this.playCount, this.lastPlayed});

  static TasteTrack? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final fp = _path(m['filepath']);
    if (fp == null) return null;
    return TasteTrack(
      fp,
      _asSimilarity(m['similarity']),
      _liteMetadata(m['metadata']),
      parseGenreTags(m['genreTags']),
      seedHash: _hash(m['seedHash']),
      playCount: _count(m['playCount']),
      lastPlayed: MusicMetadata.utcOrNull(m['lastPlayed']),
    );
  }
}

/// One album card: the `/db/albums` Album shape (identity = name + year +
/// album_art_file, so it opens through the same album-songs body) plus the
/// match and this account's play facts over the tracks it can see.
class TasteAlbum {
  final String name;
  final int? year;
  final String? albumArtFile;

  /// The group's single credit; null when its rows disagree (a compilation)
  /// — see albumSongsBody.
  final String? albumArtist;
  final List<String> artists;

  /// All-libraries count, as `/db/albums` reports it.
  final int? trackCount;
  final double similarity;

  /// Tracks in the caller's libraries, and how many of those were played.
  final int? scopedTracks;
  final int? playedTracks;
  final DateTime? lastPlayed;

  /// The album's tracks as vpath-form paths (no leading slash); these are
  /// left out of the library's song list.
  final List<String> tracks;

  TasteAlbum(this.name,
      {this.year,
      this.albumArtFile,
      this.albumArtist,
      this.artists = const [],
      this.trackCount,
      this.similarity = 0,
      this.scopedTracks,
      this.playedTracks,
      this.lastPlayed,
      this.tracks = const []});

  static TasteAlbum? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final name = _str(m['name']);
    if (name == null) return null;
    final artists = m['artists'];
    final tracks = m['tracks'];
    return TasteAlbum(
      name,
      year: _int(m['year']),
      albumArtFile: _path(m['album_art_file']),
      albumArtist: _str(m['album_artist']),
      artists: artists is List
          ? artists.map(_str).whereType<String>().toList()
          : const [],
      trackCount: _count(m['track_count']),
      similarity: _asSimilarity(m['similarity']),
      scopedTracks: _count(m['scopedTracks']),
      playedTracks: _count(m['playedTracks']),
      lastPlayed: MusicMetadata.utcOrNull(m['lastPlayed']),
      tracks: tracks is List
          ? tracks.map(_path).whereType<String>().toList()
          : const [],
    );
  }

  /// No track of it played by this account (as far as the server said).
  bool get unplayed => playedTracks == 0;
}

/// The library source: albums before songs (plan §2.6), under the fixed
/// rule "songs you haven't played lately" (never, or more than 90 days ago).
class TasteLibrary {
  final List<TasteTrack> tracks;
  final List<TasteAlbum> albums;

  /// The walk hit its budget before the limits filled — "there may be more".
  final bool capped;

  TasteLibrary(this.tracks, this.albums, this.capped);

  factory TasteLibrary.fromServerMap(Map m) => TasteLibrary(
        _listOf(m['tracks'], TasteTrack.fromServerMap),
        _listOf(m['albums'], TasteAlbum.fromServerMap),
        m['capped'] == true,
      );
}

/// The network source: P2P leads (no plug-in verbs in v1 on mobile — they
/// behave like the per-song Discover screen's network rows).
class TasteLeads {
  final int searchedPeers;
  final int searchedTracks;
  final List<DiscoveryLead> results;

  TasteLeads(this.searchedPeers, this.searchedTracks, this.results);

  factory TasteLeads.fromServerMap(Map m) {
    final searched = m['searched'];
    return TasteLeads(
      searched is Map ? _count(searched['peers']) ?? 0 : 0,
      searched is Map ? _count(searched['tracks']) ?? 0 : 0,
      _listOf(m['results'], DiscoveryLead.fromServerMap),
    );
  }
}

/// One federated peer's answer: its state for this call and its rows.
class TastePeerGroup {
  /// The peer's row id on this server — what its stream proxy keys on.
  final int? id;
  final String name;

  /// This call's outcome, not a stored status.
  final bool reachable;

  /// The peer runs a different embedding model, so its vectors cannot be
  /// compared.
  final bool mismatched;

  /// The server's federation_peers record — may be stale.
  final DateTime? lastSeen;
  final List<DiscoveryLead> results;

  TastePeerGroup(this.id, this.name, this.reachable, this.mismatched,
      this.lastSeen, this.results);

  static TastePeerGroup? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final id = _count(m['id']);
    final name = _str(m['name']) ?? '';
    final raw = m['results'];
    final results = raw is List
        ? raw
            .map((r) =>
                DiscoveryLead.fromServerMap(r, peerId: id, peerName: name))
            .whereType<DiscoveryLead>()
            .toList()
        : <DiscoveryLead>[];
    return TastePeerGroup(
      id,
      name,
      m['reachable'] is bool ? m['reachable'] as bool : results.isNotEmpty,
      m['mismatched'] == true,
      MusicMetadata.utcOrNull(m['lastSeen']),
      results,
    );
  }
}

/// The peers source: grouped by peer (plan §6.5).
class TastePeers {
  final List<TastePeerGroup> peers;
  final int searchedPeers;
  final int unreachablePeers;
  final int mismatchedPeers;

  TastePeers(this.peers, this.searchedPeers, this.unreachablePeers,
      this.mismatchedPeers);

  factory TastePeers.fromServerMap(Map m) {
    final searched = m['searched'];
    int count(String key) => searched is Map ? _count(searched[key]) ?? 0 : 0;
    return TastePeers(
      _listOf(m['peers'], TastePeerGroup.fromServerMap),
      count('peers'),
      count('unreachable'),
      count('mismatched'),
    );
  }

  /// Every peer's rows, in group order.
  List<DiscoveryLead> get allResults =>
      [for (final g in peers) ...g.results];
}

/// The embedding model the answer was computed with.
class TasteModel {
  final String? id;
  final String? version;

  TasteModel(this.id, this.version);

  static TasteModel? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final id = _str(m['id']);
    final v = m['version'];
    final version = v is num ? v.toString() : _str(v);
    if (id == null && version == null) return null;
    return TasteModel(id, version);
  }
}

/// `POST /api/v1/discovery/taste` response.
class TasteResponse {
  /// The window the server applied (days; 0 = all time).
  final int? window;

  /// The requested window when it yielded nothing and the server widened.
  final int? widenedFrom;
  final TasteSeedSource? seedSource;

  /// Nothing to seed from at all: one random analyzed track stands in, and
  /// the network / peers fan-outs were skipped.
  final bool fallback;
  final List<TasteSeed> seeds;
  final List<TasteExcluded> excluded;

  /// Pins the server dropped (unknown or not visible to this account).
  final int dropped;

  /// Discovery is on but the scan has not produced vectors yet.
  final bool notAnalyzed;
  final TasteModel? model;

  /// Null when not asked for.
  final TasteLibrary? library;

  /// Null when not asked for, not advertised for this account, or a random
  /// seed is in use; empty results when asked and nothing matched.
  final TasteLeads? network;
  final TastePeers? peers;

  TasteResponse({
    this.window,
    this.widenedFrom,
    this.seedSource,
    this.fallback = false,
    this.seeds = const [],
    this.excluded = const [],
    this.dropped = 0,
    this.notAnalyzed = false,
    this.model,
    this.library,
    this.network,
    this.peers,
  });

  factory TasteResponse.fromServerMap(Map m) {
    final library = m['library'];
    final network = m['network'];
    final peers = m['peers'];
    return TasteResponse(
      window: _count(m['window']),
      widenedFrom: _count(m['widenedFrom']),
      seedSource: TasteSeedSource.parse(m['seedSource']),
      fallback: m['fallback'] == true,
      seeds: _listOf(m['seeds'], TasteSeed.fromServerMap),
      excluded: _listOf(m['excluded'], TasteExcluded.fromServerMap),
      dropped: _count(m['dropped']) ?? 0,
      notAnalyzed: m['notAnalyzed'] == true,
      model: TasteModel.fromServerMap(m['model']),
      library: library is Map ? TasteLibrary.fromServerMap(library) : null,
      network: network is Map ? TasteLeads.fromServerMap(network) : null,
      peers: peers is Map ? TastePeers.fromServerMap(peers) : null,
    );
  }
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

// ─── Wire sanitisers ─────────────────────────────────────────────────────
// The caps follow the server's recommendation schema
// (src/discovery-plugins/recommendation.js): text 512, filepath 2048, and
// the taste body's 128-char hash. Over-cap is treated as absent, not
// truncated — a cut path or hash would name something else.

String? _str(dynamic v, {int max = 512}) =>
    v is String && v.trim().isNotEmpty && v.length <= max ? v : null;

/// A vpath-form path as sent — never trimmed, since a path is an identity.
String? _path(dynamic v) => _str(v, max: 2048);

String? _hash(dynamic v) => _str(v, max: 128);

/// A cached cover's file name, by the server's own rule (mStream
/// src/api/discovery-federation.js ART_NAME, the album-art cache's names: an
/// md5 hash plus its extension). Nothing else — no '/', '%', '?', dot
/// segment or space — is spliced into the art proxy's path.
final RegExp _artNameRule = RegExp(r'^[a-zA-Z0-9_-]{1,100}\.[a-zA-Z0-9]{1,7}$');
String? _artName(dynamic v) =>
    v is String && _artNameRule.hasMatch(v) ? v : null;

/// An integer from a num (rounded) or a numeric string; null otherwise.
int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.round() : null;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// A count or id: a non-negative integer, else null.
int? _count(dynamic v) {
  final i = _int(v);
  return i != null && i >= 0 ? i : null;
}

String _stripSlash(String p) => p.startsWith('/') ? p.substring(1) : p;

/// The valid hashes of an oldest-first exclusion list, newest
/// [kTasteExcludeMax] kept: the server trims the same way, and one over the
/// cap would 400 the whole call.
List<String> _newestHashes(List<String> hashes) {
  final valid = hashes.where((h) => _hash(h) != null).toList();
  return valid.length > kTasteExcludeMax
      ? valid.sublist(valid.length - kTasteExcludeMax)
      : valid;
}

List<T> _listOf<T>(dynamic v, T? Function(dynamic) parse) =>
    v is List ? v.map(parse).whereType<T>().toList() : <T>[];

/// A shallow copy of a wire row with its string keys, read-only — the row a
/// later resolve forwards unchanged.
Map<String, dynamic> _rawCopy(Map m) => Map.unmodifiable(<String, dynamic>{
      for (final e in m.entries)
        if (e.key is String) e.key as String: e.value,
    });

/// A server LITE metadata block as [MusicMetadata], or null. fromServerMap
/// coerces most fields itself but hands a few straight to typed slots (the
/// text fields, hash, track / disk / year / bpm), where a wrong-typed value
/// would throw out of the whole parse; those are checked here first — a bad
/// value is dropped, a fractional number rounded.
MusicMetadata? _liteMetadata(dynamic md) {
  if (md is! Map) return null;
  final m = <String, dynamic>{
    for (final e in md.entries)
      if (e.key is String) e.key as String: e.value,
  };
  void keep(String key, Object? value) =>
      value == null ? m.remove(key) : m[key] = value;
  for (final k in const ['artist', 'album', 'title', 'musical-key']) {
    keep(k, _str(m[k]));
  }
  keep('album-art', _path(m['album-art']));
  keep('hash', _hash(m['hash']));
  for (final k in const ['track', 'disk', 'disc', 'year', 'bpm']) {
    keep(k, _int(m[k]));
  }
  return MusicMetadata.fromServerMap(m);
}
