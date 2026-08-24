import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/metadata.dart';

void main() {
  // An entry from before queueExtras: the shape Auto DJ used to write. No
  // hasLyrics / bitrate / format, and its own transparency keys.
  MediaItem legacyDjItem(String path, {String server = 's1'}) => MediaItem(
        id: 'http://host/media$path',
        title: 'T',
        extras: {
          'server': server,
          'path': path,
          'rating': 8,
          'year': 2018,
          'artUrl': 'http://host/album-art/a.jpg',
          'bpm': 128,
          'musicalKey': 'F#m',
          'djPick': true,
          'djSonic': false,
        },
      );

  MusicMetadata meta() => MusicMetadata(
        'Artist', 'Album', 'Title', 3, 1, 2020, 'hash', 2, 'art.jpg',
        bpm: 90,
        musicalKey: 'Am',
        bitrate: 320000,
        sampleRate: 44100,
        format: 'flac',
        trackTotal: 12,
        hasLyrics: true,
      );

  group('AudioPlayerHandler.patchQueueExtras', () {
    test('adds the missing keys and keeps the ones already there', () {
      final q = [legacyDjItem('/a.mp3'), legacyDjItem('/b.mp3')];
      final patched = AudioPlayerHandler.patchQueueExtras(q,
          serverName: 's1', path: '/b.mp3', meta: meta());

      expect(patched, isNotNull);
      // Untouched items keep their instance — the caller swaps sources by
      // identity (see patchDownloadedTrack).
      expect(identical(patched![0], q[0]), isTrue);

      final e = patched[1].extras!;
      // What was missing is now there.
      expect(e['hasLyrics'], isTrue);
      expect(e['bitrate'], 320000);
      expect(e['sampleRate'], 44100);
      expect(e['format'], 'flac');
      expect(e['trackTotal'], 12);
      // What the item already knew wins over the fetched copy: the rating the
      // user set, the DJ's transparency keys, and the bpm/key the DJ's
      // continuity payload reads.
      expect(e['rating'], 8);
      expect(e['bpm'], 128);
      expect(e['musicalKey'], 'F#m');
      expect(e['year'], 2018);
      expect(e['djPick'], isTrue);
      expect(e['djSonic'], isFalse);
    });

    test('leaves an already-complete entry alone', () {
      final q = [
        MediaItem(id: 'x', title: 'T', extras: {
          'server': 's1',
          'path': '/b.mp3',
          // Present-but-false is still present: only an ABSENT hasLyrics
          // marks an entry as predating queueExtras.
          'hasLyrics': false,
        })
      ];
      expect(
          AudioPlayerHandler.patchQueueExtras(q,
              serverName: 's1', path: '/b.mp3', meta: meta()),
          isNull);
    });

    test('ignores the same path on a different server', () {
      final q = [legacyDjItem('/b.mp3', server: 's2')];
      expect(
          AudioPlayerHandler.patchQueueExtras(q,
              serverName: 's1', path: '/b.mp3', meta: meta()),
          isNull);
    });

    test('patches every copy of the track in the queue', () {
      final q = [legacyDjItem('/b.mp3'), legacyDjItem('/a.mp3'), legacyDjItem('/b.mp3')];
      final patched = AudioPlayerHandler.patchQueueExtras(q,
          serverName: 's1', path: '/b.mp3', meta: meta())!;
      expect(patched[0].extras!['hasLyrics'], isTrue);
      expect(identical(patched[1], q[1]), isTrue);
      expect(patched[2].extras!['hasLyrics'], isTrue);
    });
  });
}
