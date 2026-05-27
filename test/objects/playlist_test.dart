import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mstream_music/objects/playlist.dart';

void main() {
  group('PlaylistEntry', () {
    test('round-trips a MediaItem through fromMediaItem/toMediaItem', () {
      final item = MediaItem(
        id: 'http://example.com/song.mp3?app_uuid=x',
        title: 'Have a Cigar',
        artist: 'Pink Floyd',
        album: 'Wish You Were Here',
        duration: Duration(minutes: 5, seconds: 8),
        extras: {'path': '/pink-floyd/wywh/03.mp3', 'year': 1975},
      );

      final entry = PlaylistEntry.fromMediaItem(item);
      final rebuilt = entry.toMediaItem();

      expect(rebuilt.id, item.id);
      expect(rebuilt.title, item.title);
      expect(rebuilt.artist, item.artist);
      expect(rebuilt.album, item.album);
      expect(rebuilt.duration, item.duration);
      expect(rebuilt.extras, item.extras);
    });

    test('round-trips through JSON', () {
      final entry = PlaylistEntry(
        id: 'id1',
        title: 't',
        artist: 'a',
        album: 'al',
        durationMs: 12345,
        extras: {'k': 'v', 'n': 1},
      );
      final reparsed = PlaylistEntry.fromJson(entry.toJson());
      expect(reparsed.id, entry.id);
      expect(reparsed.title, entry.title);
      expect(reparsed.artist, entry.artist);
      expect(reparsed.album, entry.album);
      expect(reparsed.durationMs, entry.durationMs);
      expect(reparsed.extras, entry.extras);
    });

    test('tolerates absent optional fields', () {
      final entry = PlaylistEntry.fromJson({'id': 'x', 'title': 'y'});
      expect(entry.id, 'x');
      expect(entry.title, 'y');
      expect(entry.artist, isNull);
      expect(entry.durationMs, isNull);
      expect(entry.extras, isEmpty);
    });
  });

  group('Playlist', () {
    test('round-trips through JSON, preserves entry order and createdAt',
        () {
      final original = Playlist(
        name: 'Mix 1',
        entries: [
          PlaylistEntry(id: 'a', title: 'A'),
          PlaylistEntry(id: 'b', title: 'B'),
          PlaylistEntry(id: 'c', title: 'C'),
        ],
        createdAt: DateTime.utc(2026, 4, 25, 14, 30),
      );

      final reparsed = Playlist.fromJson(original.toJson());

      expect(reparsed.name, 'Mix 1');
      expect(reparsed.entries.length, 3);
      expect(reparsed.entries.map((e) => e.id).toList(), ['a', 'b', 'c']);
      expect(reparsed.createdAt.toUtc(), DateTime.utc(2026, 4, 25, 14, 30));
    });

    test('defaults entries to empty when absent in JSON', () {
      final p = Playlist.fromJson({'name': 'empty'});
      expect(p.name, 'empty');
      expect(p.entries, isEmpty);
    });
  });
}
