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

  group('QueueStore.clampResumePositionMs', () {
    test('keeps a mid-track position', () {
      expect(QueueStore.clampResumePositionMs(23000, 240000), 23000);
    });
    test('resets a position at or past the end to 0', () {
      expect(QueueStore.clampResumePositionMs(240000, 240000), 0);
      expect(QueueStore.clampResumePositionMs(999999, 240000), 0);
    });
    test('resets a position within 1s of the end to 0', () {
      expect(QueueStore.clampResumePositionMs(239500, 240000), 0);
    });
    test('keeps a position more than 1s before the end', () {
      expect(QueueStore.clampResumePositionMs(238000, 240000), 238000);
    });
    test('leaves the position unchanged when the duration is unknown', () {
      expect(QueueStore.clampResumePositionMs(700000, null), 700000);
      expect(QueueStore.clampResumePositionMs(700000, 0), 700000);
    });
    test('floors a non-positive position to 0', () {
      expect(QueueStore.clampResumePositionMs(-5, 240000), 0);
      expect(QueueStore.clampResumePositionMs(0, 240000), 0);
    });
  });

  group('QueueStore snapshot peeks (resumption chip)', () {
    Map<String, dynamic> snapshot({int index = 1, int version = 1}) => {
          'version': version,
          'index': index,
          'positionMs': 1000,
          'shuffle': false,
          'repeat': 'none',
          'items': [
            {
              'title': 'First',
              'extras': {'server': 's1', 'path': '/a.mp3'},
            },
            {
              'title': 'Second',
              'artist': 'Artist',
              'album': 'Album',
              'extras': {
                'server': 's1',
                'path': '/b.mp3',
                'artUrl': 'http://host/album-art/b.jpg',
              },
            },
          ],
        };

    test('currentEntryFromSnapshot returns the saved-index entry', () {
      final entry = QueueStore.currentEntryFromSnapshot(snapshot());
      expect(entry, isNotNull);
      expect(entry!['title'], 'Second');
    });

    test('out-of-range index clamps to the first item (like restore)', () {
      expect(QueueStore.currentEntryFromSnapshot(snapshot(index: 7))!['title'],
          'First');
      expect(QueueStore.currentEntryFromSnapshot(snapshot(index: -2))!['title'],
          'First');
    });

    test('wrong schema version / shape / empty items -> null', () {
      expect(QueueStore.currentEntryFromSnapshot(snapshot(version: 2)), isNull);
      expect(QueueStore.currentEntryFromSnapshot('junk'), isNull);
      expect(QueueStore.currentEntryFromSnapshot(null), isNull);
      expect(
          QueueStore.currentEntryFromSnapshot(
              {'version': 1, 'index': 0, 'items': <dynamic>[]}),
          isNull);
    });

    test('resumeItemFromSnapshot builds display metadata + carries artUrl', () {
      final item = QueueStore.resumeItemFromSnapshot(
          QueueStore.currentEntryFromSnapshot(snapshot()));
      expect(item, isNotNull);
      expect(item!.title, 'Second');
      expect(item.artist, 'Artist');
      expect(item.album, 'Album');
      expect(item.playable, isTrue);
      expect(item.extras!['artUrl'], 'http://host/album-art/b.jpg');
    });

    test('missing title falls back to the path basename', () {
      final item = QueueStore.resumeItemFromSnapshot({
        'extras': {'path': '/music/deep/track.flac'},
      });
      expect(item, isNotNull);
      expect(item!.title, 'track.flac');
    });

    test('no title and no path -> null (nothing worth a chip)', () {
      expect(QueueStore.resumeItemFromSnapshot({'extras': {}}), isNull);
      expect(QueueStore.resumeItemFromSnapshot(null), isNull);
    });

    test('the peeked item survives a JSON text round-trip of the snapshot', () {
      final raw = jsonDecode(jsonEncode(snapshot()));
      final item = QueueStore.resumeItemFromSnapshot(
          QueueStore.currentEntryFromSnapshot(raw));
      expect(item!.title, 'Second');
    });
  });
}
