import 'dart:convert';

/// How a play session ended.
///
/// Independent of whether it COUNTED as a play (see [countsAsPlay]): a skip
/// three minutes into a five-minute track is `skipped` and a counted play.
enum PlayOutcome { completed, skipped, stopped }

/// How the track came to be playing. The names are the server's `source`
/// vocabulary (Stats API v2) and go on the wire unchanged.
enum PlaySource { manual, shuffle, autodj, playlist, auto, carplay, cast, other }

/// The server's play-threshold rule, mirrored so the device's own counts
/// agree with what the server will decide at ingest: at least 30 seconds
/// listened, or at least half the track. Both are constants here and config
/// on the server; a change is a change in both places.
const int kPlayThresholdMs = 30000;
const double kPlayThresholdFraction = 0.5;

bool countsAsPlay({required int playedMs, int? durationMs}) {
  if (playedMs >= kPlayThresholdMs) return true;
  if (durationMs == null || durationMs <= 0) return false;
  return playedMs >= durationMs * kPlayThresholdFraction;
}

/// What the tracker knows about a track when its session opens — copied
/// out of the queue item so an event renders offline with no fetch, and so
/// a federated play carries the snapshot the parent server needs.
class TrackFacts {
  /// Server localname; empty for a purely local (on-device) file.
  final String server;

  /// For a federated server: the peer's row id ON ITS PARENT — what the
  /// sync layer sends as `peerId` when it routes the event to the parent.
  final int? peerId;

  /// The app's path for the track (server tracks: the library path with the
  /// leading slash the queue keeps; local files: the absolute path).
  final String path;
  final String? hash;
  final String? title;
  final String? artist;
  final String? album;

  /// The album-art file name on the server (the `/album-art/<file>` name),
  /// when the queue item carried an art URL.
  final String? artFile;
  final int? durationMs;

  const TrackFacts({
    required this.server,
    this.peerId,
    required this.path,
    this.hash,
    this.title,
    this.artist,
    this.album,
    this.artFile,
    this.durationMs,
  });

  bool get isLocalFile => server.isEmpty;

  TrackFacts withDuration(int? durationMs) => TrackFacts(
        server: server,
        peerId: peerId,
        path: path,
        hash: hash,
        title: title,
        artist: artist,
        album: album,
        artFile: artFile,
        durationMs: durationMs,
      );

  Map<String, dynamic> toJson() => {
        'srv': server,
        'peer': peerId,
        'p': path,
        'h': hash,
        'ti': title,
        'ar': artist,
        'al': album,
        'art': artFile,
        'dur': durationMs,
      };

  static TrackFacts? fromJson(Map<dynamic, dynamic> j) {
    final path = j['p'];
    if (path is! String || path.isEmpty) return null;
    return TrackFacts(
      server: j['srv'] is String ? j['srv'] as String : '',
      peerId: j['peer'] is int ? j['peer'] as int : null,
      path: path,
      hash: j['h'] is String ? j['h'] as String : null,
      title: j['ti'] is String ? j['ti'] as String : null,
      artist: j['ar'] is String ? j['ar'] as String : null,
      album: j['al'] is String ? j['al'] as String : null,
      artFile: j['art'] is String ? j['art'] as String : null,
      durationMs: j['dur'] is int ? j['dur'] as int : null,
    );
  }
}

/// One closed play session: what was played, when, for how long, and how it
/// ended. Immutable. Serialized as one compact JSON line on the device and
/// as the Stats API v2 shape on the wire ([toWire]).
class PlayEvent {
  static const int schemaVersion = 1;

  /// Client UUID — the server's idempotency key.
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final TrackFacts track;
  final int playedMs;
  final PlayOutcome outcome;
  final PlaySource source;
  final int pauseCount;

  /// The local verdict under [countsAsPlay]. The server recomputes it at
  /// ingest; this one drives the device's own counters.
  final bool counted;

  const PlayEvent({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.track,
    required this.playedMs,
    required this.outcome,
    required this.source,
    this.pauseCount = 0,
    required this.counted,
  });

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'id': id,
        't': startedAt.millisecondsSinceEpoch,
        'e': endedAt.millisecondsSinceEpoch,
        ...track.toJson(),
        'pl': playedMs,
        'o': outcome.name,
        's': source.name,
        'pz': pauseCount,
        'c': counted,
      };

  String toJsonLine() => jsonEncode(toJson());

  /// Null for anything that isn't a complete event — a torn line, a future
  /// schema, a hand-edited file. Readers skip nulls.
  static PlayEvent? fromJson(Map<dynamic, dynamic> j) {
    final id = j['id'];
    final t = j['t'];
    final pl = j['pl'];
    if (id is! String || id.isEmpty || t is! int || pl is! int) return null;
    final track = TrackFacts.fromJson(j);
    if (track == null) return null;
    final outcome = PlayOutcome.values.cast<PlayOutcome?>().firstWhere(
        (o) => o!.name == j['o'],
        orElse: () => null);
    if (outcome == null) return null;
    final source = PlaySource.values.cast<PlaySource?>().firstWhere(
            (s) => s!.name == j['s'],
            orElse: () => null) ??
        PlaySource.other;
    final e = j['e'];
    final startedAt = DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
    return PlayEvent(
      id: id,
      startedAt: startedAt,
      endedAt: e is int
          ? DateTime.fromMillisecondsSinceEpoch(e, isUtc: true)
          : startedAt.add(Duration(milliseconds: pl)),
      track: track,
      playedMs: pl,
      outcome: outcome,
      source: source,
      pauseCount: j['pz'] is int ? j['pz'] as int : 0,
      counted: j['c'] == true,
    );
  }

  static PlayEvent? fromJsonLine(String line) {
    try {
      final v = jsonDecode(line);
      return v is Map ? fromJson(v) : null;
    } catch (_) {
      return null;
    }
  }

  /// The Stats API v2 `plays[]` element. The server resolves the path
  /// itself, so the leading slash the queue keeps is stripped (as
  /// `rateSong` does); a federated play adds `peerId` and the snapshot the
  /// parent can't look up.
  Map<String, dynamic> toWire() {
    final filePath =
        track.path.startsWith('/') ? track.path.substring(1) : track.path;
    return {
      'id': id,
      'filePath': filePath,
      if (track.peerId != null) 'peerId': track.peerId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'playedMs': playedMs,
      if (track.durationMs != null) 'durationMs': track.durationMs,
      'outcome': outcome.name,
      'source': source.name,
      'pauseCount': pauseCount,
      if (track.peerId != null)
        'track': {
          if (track.title != null) 'title': track.title,
          if (track.artist != null) 'artist': track.artist,
          if (track.album != null) 'album': track.album,
          if (track.durationMs != null) 'durationMs': track.durationMs,
          if (track.hash != null) 'hash': track.hash,
          if (track.artFile != null) 'artFile': track.artFile,
        },
    };
  }
}
