import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/queue_store.dart';

void main() {
  // Simulate a real save→load: encode to JSON text and back, the way the file
  // round-trips it, before rebuilding.
  Map<String, dynamic> roundTripJson(MediaItem m) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(QueueStore.itemToJson(m))));

  group('QueueStore.itemToJson', () {
    test('captures the display fields, duration (ms) and extras', () {
      final m = MediaItem(
        id: 'http://host/media/x',
        title: 'Title',
        album: 'Album',
        artist: 'Artist',
        genre: 'Genre',
        duration: const Duration(milliseconds: 1234),
        extras: {'server': 's', 'path': '/x', 'track': 3},
      );

      final json = QueueStore.itemToJson(m);

      expect(json['title'], 'Title');
      expect(json['album'], 'Album');
      expect(json['artist'], 'Artist');
      expect(json['genre'], 'Genre');
      expect(json['durationMs'], 1234);
      expect(json['extras'], {'server': 's', 'path': '/x', 'track': 3});
      // The whole thing must survive a JSON text round-trip.
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('null duration serializes as null durationMs', () {
      final m = MediaItem(id: 'id', title: 'T', extras: {'path': '/p'});
      expect(QueueStore.itemToJson(m)['durationMs'], isNull);
    });
  });

  group('QueueStore.itemFromJson — local files', () {
    test('round-trips and keeps the id + localPath as-is', () {
      final original = MediaItem(
        id: 'local-uuid-1',
        title: 'song.mp3',
        extras: {
          'path': '/sdcard/Music/song.mp3',
          'localPath': '/sdcard/Music/song.mp3',
        },
      );

      final restored = QueueStore.itemFromJson(roundTripJson(original));

      expect(restored, isNotNull);
      expect(restored!.id, 'local-uuid-1');
      expect(restored.title, 'song.mp3');
      expect(restored.extras!['localPath'], '/sdcard/Music/song.mp3');
    });
  });

  group('QueueStore.itemFromJson — server files', () {
    final server = Server('http://host:3000', null, null, 'tok123', 'myserver');

    test('rebuilds the streaming URL with the CURRENT token + encoded path', () {
      final original = MediaItem(
        // A stale URL with an old token — must NOT be reused.
        id: 'http://host:3000/media/Music/foo%20bar.mp3?app_uuid=OLD&token=STALE',
        title: 'Foo Bar',
        album: 'The Album',
        artist: 'The Artist',
        genre: 'Rock',
        duration: const Duration(milliseconds: 215000),
        extras: {
          'server': 'myserver',
          'path': '/Music/foo bar.mp3',
          'year': 2021,
          'track': 3,
          'disc': 1,
          'artUrl': 'http://host:3000/album-art/abc?token=STALE',
          'bpm': 128,
          'musicalKey': '8A',
        },
      );

      final restored = QueueStore.itemFromJson(
        roundTripJson(original),
        resolveServer: (name) => name == 'myserver' ? server : null,
      );

      expect(restored, isNotNull);
      // Display fields preserved.
      expect(restored!.title, 'Foo Bar');
      expect(restored.album, 'The Album');
      expect(restored.artist, 'The Artist');
      expect(restored.genre, 'Rock');
      expect(restored.duration, const Duration(milliseconds: 215000));
      // Extras preserved.
      expect(restored.extras!['path'], '/Music/foo bar.mp3');
      expect(restored.extras!['bpm'], 128);
      expect(restored.extras!['musicalKey'], '8A');
      // URL rebuilt fresh: correct host + transcode-off prefix + encoded path,
      // the current token, a new app_uuid — and crucially NOT the stale token.
      expect(restored.id, startsWith('http://host:3000/media/Music/foo%20bar.mp3'));
      expect(restored.id, contains('token=tok123'));
      expect(restored.id, contains('app_uuid='));
      expect(restored.id, isNot(contains('STALE')));
    });

    test('returns null when the server is no longer configured', () {
      final original = MediaItem(
        id: 'http://host:3000/media/x',
        title: 'Orphan',
        extras: {'server': 'goneserver', 'path': '/x'},
      );

      final restored = QueueStore.itemFromJson(
        roundTripJson(original),
        resolveServer: (_) => null,
      );

      expect(restored, isNull);
    });

    test('returns null when a server item is missing its path', () {
      final original = MediaItem(
        id: 'http://host:3000/media/x',
        title: 'No Path',
        extras: {'server': 'myserver'},
      );

      final restored = QueueStore.itemFromJson(
        roundTripJson(original),
        resolveServer: (_) => server,
      );

      expect(restored, isNull);
    });
  });
}
