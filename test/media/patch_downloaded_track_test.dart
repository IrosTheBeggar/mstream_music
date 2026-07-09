import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  MediaItem serverItem(String path,
          {String server = 's1', String? localPath, String title = 'T'}) =>
      MediaItem(
        id: 'http://host/media$path?token=t',
        title: title,
        extras: {
          'server': server,
          'path': path,
          'localPath': ?localPath,
          'artUrl': 'http://host/album-art/a.jpg',
        },
      );

  group('AudioPlayerHandler.patchDownloadedTrack', () {
    // A completed download must flip queued copies of exactly that track to
    // the local file — and nothing else: instance identity of untouched items
    // is load-bearing (the caller swaps backend sources by identity).

    test('patches the matching copy and preserves the other extras', () {
      final q = [serverItem('/a.mp3'), serverItem('/b.mp3')];
      final patched = AudioPlayerHandler.patchDownloadedTrack(q,
          serverName: 's1', path: '/b.mp3', localPath: '/dl/s1/b.mp3');

      expect(patched, isNotNull);
      expect(identical(patched![0], q[0]), isTrue);
      expect(patched[1].extras!['localPath'], '/dl/s1/b.mp3');
      expect(patched[1].extras!['artUrl'], 'http://host/album-art/a.jpg');
      expect(patched[1].id, q[1].id, reason: 'stream URL kept as fallback');
    });

    test('patches every queued copy of the track', () {
      final q = [
        serverItem('/a.mp3'),
        serverItem('/a.mp3'),
        serverItem('/b.mp3'),
      ];
      final patched = AudioPlayerHandler.patchDownloadedTrack(q,
          serverName: 's1', path: '/a.mp3', localPath: '/dl/a.mp3')!;
      expect(patched[0].extras!['localPath'], '/dl/a.mp3');
      expect(patched[1].extras!['localPath'], '/dl/a.mp3');
      expect(identical(patched[2], q[2]), isTrue);
    });

    test('copies already carrying this exact path are left untouched', () {
      final q = [serverItem('/a.mp3', localPath: '/dl/a.mp3')];
      expect(
        AudioPlayerHandler.patchDownloadedTrack(q,
            serverName: 's1', path: '/a.mp3', localPath: '/dl/a.mp3'),
        isNull,
        reason: 'nothing changed → null so the caller can skip all work',
      );
    });

    test('a STALE localPath is re-patched to the fresh location', () {
      // Storage-location change: "Delete old downloads — they'll re-download
      // at the new location". The queued copy's old path must not block the
      // re-download's patch, or it streams forever while showing "downloaded".
      final q = [serverItem('/a.mp3', localPath: '/old-storage/a.mp3')];
      final patched = AudioPlayerHandler.patchDownloadedTrack(q,
          serverName: 's1', path: '/a.mp3', localPath: '/new-storage/a.mp3');
      expect(patched, isNotNull);
      expect(patched![0].extras!['localPath'], '/new-storage/a.mp3');
    });

    test('same path on a DIFFERENT server does not match', () {
      final q = [serverItem('/a.mp3', server: 's2')];
      expect(
        AudioPlayerHandler.patchDownloadedTrack(q,
            serverName: 's1', path: '/a.mp3', localPath: '/dl/a.mp3'),
        isNull,
      );
    });

    test('items without extras are safe and untouched', () {
      final q = [const MediaItem(id: 'x', title: 'no extras')];
      expect(
        AudioPlayerHandler.patchDownloadedTrack(q,
            serverName: 's1', path: '/a.mp3', localPath: '/dl/a.mp3'),
        isNull,
      );
    });

    test('track not in the queue → null (the common browser-download case)',
        () {
      final q = [serverItem('/a.mp3')];
      expect(
        AudioPlayerHandler.patchDownloadedTrack(q,
            serverName: 's1', path: '/zzz.mp3', localPath: '/dl/zzz.mp3'),
        isNull,
      );
    });
  });
}
