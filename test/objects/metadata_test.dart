import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/metadata.dart';

void main() {
  group('MusicMetadata.fromJson', () {
    test('parses a typical track payload', () {
      final m = MusicMetadata.fromJson({
        'artist': 'Pink Floyd',
        'album': 'Wish You Were Here',
        'title': 'Have a Cigar',
        'track': 3,
        'disc': 1,
        'year': 1975,
        'hash': 'abc123',
        'rating': 8,
        'albumArt': 'pf-wywh.jpg',
      });
      expect(m.artist, 'Pink Floyd');
      expect(m.album, 'Wish You Were Here');
      expect(m.title, 'Have a Cigar');
      expect(m.track, 3);
      expect(m.disc, 1);
      expect(m.year, 1975);
      expect(m.hash, 'abc123');
      expect(m.rating, 8);
      expect(m.albumArt, 'pf-wywh.jpg');
    });

    test('tolerates null optional fields', () {
      final m = MusicMetadata.fromJson({
        'artist': null,
        'album': null,
        'title': null,
        'track': null,
        'disc': null,
        'year': null,
        'hash': 'h',
        'rating': null,
        'albumArt': null,
      });
      expect(m.hash, 'h');
      expect(m.artist, isNull);
      expect(m.title, isNull);
      expect(m.year, isNull);
    });
  });

  group('MusicMetadata.toJson', () {
    test('round-trips through fromJson', () {
      final original = MusicMetadata(
          'Artist', 'Album', 'Title', 5, 2, 2024, 'h1', 9, 'art.jpg');
      final reparsed = MusicMetadata.fromJson(original.toJson());

      expect(reparsed.artist, original.artist);
      expect(reparsed.album, original.album);
      expect(reparsed.title, original.title);
      expect(reparsed.track, original.track);
      expect(reparsed.disc, original.disc);
      expect(reparsed.year, original.year);
      expect(reparsed.hash, original.hash);
      expect(reparsed.rating, original.rating);
      expect(reparsed.albumArt, original.albumArt);
    });

    test('round-trips the audio-spec fields', () {
      final original = MusicMetadata(
          'A', 'Al', 'Ti', 1, 1, 2020, 'h', 5, 'art.jpg',
          durationSeconds: 200.0, bitrate: 1000, sampleRate: 44100);
      final reparsed = MusicMetadata.fromJson(original.toJson());
      expect(reparsed.durationSeconds, 200.0);
      expect(reparsed.bitrate, 1000);
      expect(reparsed.sampleRate, 44100);
    });
  });

  // The album detail screen renders duration / bitrate / sample-rate only when
  // present, so the client must parse them off newer servers AND leave them null
  // on older builds that don't send them.
  group('MusicMetadata.fromServerMap progressive fields', () {
    test('reads duration / bitrate / sample-rate when present', () {
      final m = MusicMetadata.fromServerMap({
        'artist': 'A',
        'title': 'T',
        'album-art': 'x.jpg',
        'duration': 225,
        'bitrate': 1411,
        'sample-rate': 44100,
      });
      expect(m.durationSeconds, 225);
      expect(m.duration, const Duration(seconds: 225));
      expect(m.bitrate, 1411);
      expect(m.sampleRate, 44100);
    });

    test('tolerates alternate key spellings and numeric strings', () {
      final m = MusicMetadata.fromServerMap({
        'hash': 'h',
        'length': '180.5',
        'bit-rate': '320',
        'sampleRate': 48000,
      });
      expect(m.durationSeconds, 180.5);
      expect(m.duration, const Duration(milliseconds: 180500));
      expect(m.bitrate, 320);
      expect(m.sampleRate, 48000);
    });

    test('leaves the new fields null on an older server (keys absent)', () {
      final m = MusicMetadata.fromServerMap({'hash': 'h', 'title': 'T'});
      expect(m.durationSeconds, isNull);
      expect(m.duration, isNull);
      expect(m.bitrate, isNull);
      expect(m.sampleRate, isNull);
    });

    test('rejects non-positive / non-numeric values', () {
      final m = MusicMetadata.fromServerMap(
          {'hash': 'h', 'duration': 0, 'bitrate': 'abc'});
      expect(m.durationSeconds, isNull);
      expect(m.duration, isNull);
      expect(m.bitrate, isNull);
    });
  });

  group('V73 credits (6.28+ servers)', () {
    test('fromServerMap reads artist-display and composer', () {
      final m = MusicMetadata.fromServerMap({
        'artist': 'Ann',
        'artist-display': 'Ann feat. Bob',
        'composer': 'Carl Composer',
        'title': 'Together',
        'hash': 'h',
      });
      expect(m.artist, 'Ann', reason: 'the primary artist stays the key');
      expect(m.artistDisplay, 'Ann feat. Bob');
      expect(m.composer, 'Carl Composer');
    });

    test('an older server leaves both null', () {
      final m = MusicMetadata.fromServerMap({'artist': 'Ann', 'hash': 'h'});
      expect(m.artistDisplay, isNull);
      expect(m.composer, isNull);
    });

    test('they round-trip through toJson / fromJson and into queueExtras', () {
      final m = MusicMetadata.fromServerMap({
        'artist': 'Ann',
        'artist-display': 'Ann feat. Bob',
        'composer': 'Carl',
        'hash': 'h',
      });
      final back = MusicMetadata.fromJson(m.toJson());
      expect(back.artistDisplay, 'Ann feat. Bob');
      expect(back.composer, 'Carl');
      final extras = queueExtras(m, server: 's', path: '/p');
      expect(extras['artistDisplay'], 'Ann feat. Bob');
      expect(extras['composer'], 'Carl');
      expect(extras['artist'], 'Ann',
          reason: 'the primary artist rides along for the name lookups');
    });
  });
}
