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
  // Genre names for this track. Velvet servers emit `metadata.genres` as a
  // string list (many-to-many via track_genres); empty when untagged or on
  // servers that don't surface genres.
  List<String> genres;

  MusicMetadata(this.artist, this.album, this.title, this.track, this.disc,
      this.year, this.hash, this.rating, this.albumArt,
      {this.bpm, this.musicalKey, this.genres = const []});

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
        m['rating'],
        m['album-art'],
        bpm: m['bpm'],
        musicalKey: m['musical-key'],
        genres: parseGenres(m['genres']),
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
}
