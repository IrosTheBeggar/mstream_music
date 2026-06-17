class MusicMetadata {
  String hash;

  String? artist;
  String? album;
  String? title;
  int? track;
  int? disc;
  int? year;
  int? rating;
  String? albumArt;
  // Tempo (BPM) and musical key — populated by the server when a
  // track is in its library DB. Both nullable since older scans
  // and untagged files won't have them. Used by AutoDJ's harmonic-
  // mixing + BPM-continuity modes (see audio_stuff.dart#autoDJ).
  int? bpm;
  String? musicalKey;
  // Per-track audio specs — present only on newer servers (and tagged files);
  // null on older API builds, so callers must treat them as optional. Used by
  // the album detail screen for per-track times, album runtime, and the
  // FLAC · kbps · kHz readout. durationSeconds is exposed as a [Duration] via
  // the [duration] getter.
  double? durationSeconds;
  int? bitrate; // bits/second (server sends raw bps; divide by 1000 for kbps)
  int? sampleRate; // Hz
  // Container/codec label (server `format`, e.g. "FLAC"); total track/disc
  // counts (`track-total`/`disc-total`, V45) so the UI can show "track N of M";
  // and this user's per-track play count (`play-count`, joined server-side on
  // every track query). All null/absent on older API builds → treat as optional.
  String? format;
  int? trackTotal;
  int? discTotal;
  int? playCount;
  // Genre names for this track. Velvet servers emit `metadata.genres` as a
  // string list (many-to-many via track_genres); empty when untagged or on
  // servers that don't surface genres.
  List<String> genres;

  MusicMetadata(this.artist, this.album, this.title, this.track, this.disc,
      this.year, this.hash, this.rating, this.albumArt,
      {this.bpm,
      this.musicalKey,
      this.genres = const [],
      this.durationSeconds,
      this.bitrate,
      this.sampleRate,
      this.format,
      this.trackTotal,
      this.discTotal,
      this.playCount});

  MusicMetadata.fromJson(Map<String, dynamic> json)
      : artist = json['artist'],
        album = json['album'],
        title = json['title'],
        track = json['track'],
        disc = json['disc'],
        year = json['year'],
        hash = json['hash'],
        rating = json['rating'],
        albumArt = json['albumArt'],
        bpm = json['bpm'],
        musicalKey = json['musicalKey'],
        durationSeconds = (json['durationSeconds'] as num?)?.toDouble(),
        bitrate = json['bitrate'],
        sampleRate = json['sampleRate'],
        format = json['format'],
        trackTotal = json['trackTotal'],
        discTotal = json['discTotal'],
        playCount = json['playCount'],
        genres = parseGenres(json['genres']);

  Map<String, dynamic> toJson() => {
        'artist': artist,
        'album': album,
        'title': title,
        'track': track,
        'disc': disc,
        'year': year,
        'hash': hash,
        'rating': rating,
        'albumArt': albumArt,
        'bpm': bpm,
        'musicalKey': musicalKey,
        'durationSeconds': durationSeconds,
        'bitrate': bitrate,
        'sampleRate': sampleRate,
        'format': format,
        'trackTotal': trackTotal,
        'discTotal': discTotal,
        'playCount': playCount,
        'genres': genres,
      };

  /// Builds a [MusicMetadata] from a raw server `metadata` map. Centralises the
  /// wire-shape quirks so every parse site stays in sync: kebab-case keys
  /// (`album-art`, `musical-key`), the disc field spelled `disk` (with a `disc`
  /// fallback), a possibly-absent `hash`, and the `genres` string list.
  factory MusicMetadata.fromServerMap(Map m) => MusicMetadata(
        m['artist'],
        m['album'],
        m['title'],
        m['track'],
        m['disk'] ?? m['disc'],
        m['year'],
        m['hash'] ?? '',
        // Coerce like the other wire numerics below: a server that sends rating
        // as a REAL or quoted value would otherwise throw on the int? field.
        _asInt(m['rating']),
        m['album-art'],
        bpm: m['bpm'],
        musicalKey: m['musical-key'],
        genres: parseGenres(m['genres']),
        // Progressive-enhancement fields — tolerate several key spellings and a
        // numeric-or-string wire type; absent on older servers → left null.
        durationSeconds: _seconds(m['duration'] ?? m['length']),
        bitrate: _asInt(m['bitrate'] ?? m['bit-rate'] ?? m['bitRate']),
        sampleRate: _asInt(m['sample-rate'] ??
            m['sampleRate'] ??
            m['samplerate'] ??
            m['sample_rate']),
        format: _asString(m['format']),
        trackTotal: _asInt(m['track-total'] ?? m['trackTotal']),
        discTotal: _asInt(m['disc-total'] ?? m['discTotal']),
        playCount: _asInt(m['play-count'] ?? m['playCount']),
      );

  /// Parses the server's `genres` value (normally a string list) into a
  /// `List<String>`, tolerating a bare string or a missing value without
  /// throwing.
  static List<String> parseGenres(dynamic value) {
    if (value is List) return value.map((g) => g.toString()).toList();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  /// The genres as a single display string (`"Rock, Electronic"`), or null when
  /// there are none — convenient for `MediaItem.genre`.
  String? get genreLabel => genres.isEmpty ? null : genres.join(', ');

  /// Track length as a [Duration], or null when the server didn't report it
  /// (older API builds / untagged files).
  Duration? get duration => durationSeconds == null
      ? null
      : Duration(milliseconds: (durationSeconds! * 1000).round());

  /// Parses a numeric seconds value (num or numeric string) to a positive
  /// double, or null when absent / non-numeric / non-positive.
  static double? _seconds(dynamic v) {
    if (v is num) return v > 0 ? v.toDouble() : null;
    if (v is String) {
      final d = double.tryParse(v);
      return (d != null && d > 0) ? d : null;
    }
    return null;
  }

  /// Parses an int from a num or numeric string, or null.
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Trims a string value; null for null / empty / non-string.
  static String? _asString(dynamic v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}
