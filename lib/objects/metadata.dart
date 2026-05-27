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

  MusicMetadata(this.artist, this.album, this.title, this.track, this.disc,
      this.year, this.hash, this.rating, this.albumArt,
      {this.bpm, this.musicalKey});

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
        musicalKey = json['musicalKey'];

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
      };
}
