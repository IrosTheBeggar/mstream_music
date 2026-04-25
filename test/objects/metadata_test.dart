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
  });
}
