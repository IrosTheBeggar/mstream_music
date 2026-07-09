import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/downloads.dart';

void main() {
  MediaItem item(String path,
          {String? server = 's1', String? localPath, String title = 'T'}) =>
      MediaItem(
        id: 'http://host/media$path',
        title: title,
        extras: {
          'server': ?server,
          'path': path,
          'localPath': ?localPath,
        },
      );

  bool onDisk(String p) => true;
  bool missing(String p) => false;

  group('DownloadManager.autoDownloadCandidates', () {
    // The keep-queue-offline sweep runs on EVERY queue emission, so the
    // selection must converge: anything picked once is marked attempted and
    // never re-picked until un-marked (terminal failure), and anything
    // already on disk / not a server track is never picked at all.

    test('picks server tracks without a local copy', () {
      final attempted = <String>{};
      final picked = DownloadManager.autoDownloadCandidates(
          [item('/a.mp3'), item('/b.mp3')], attempted,
          fileExists: onDisk);
      expect(picked.length, 2);
      expect(attempted, {'s1/a.mp3', 's1/b.mp3'});
    });

    test('skips tracks whose file is really on disk, and local-only items',
        () {
      final picked = DownloadManager.autoDownloadCandidates([
        item('/a.mp3', localPath: '/dl/a.mp3'),
        item('/b.mp3', server: null), // file-explorer track — nothing to fetch
      ], <String>{}, fileExists: onDisk);
      expect(picked, isEmpty);
    });

    test('a DEAD localPath (file deleted / SD ejected) is a candidate again',
        () {
      // Playback consumers probe localPath and silently fall back to
      // streaming when the file is gone — the sweep must probe too, or the
      // track is permanently exempt while quietly streaming.
      final picked = DownloadManager.autoDownloadCandidates(
          [item('/a.mp3', localPath: '/gone/a.mp3')], <String>{},
          fileExists: missing);
      expect(picked.length, 1);
    });

    test('a repeat sweep picks nothing (converges)', () {
      final attempted = <String>{};
      final q = [item('/a.mp3')];
      expect(
          DownloadManager.autoDownloadCandidates(q, attempted,
                  fileExists: onDisk)
              .length,
          1);
      expect(
          DownloadManager.autoDownloadCandidates(q, attempted,
              fileExists: onDisk),
          isEmpty);
    });

    test('un-marking (terminal failure) makes the track retryable', () {
      final attempted = <String>{};
      final q = [item('/a.mp3')];
      DownloadManager.autoDownloadCandidates(q, attempted, fileExists: onDisk);
      attempted.remove('s1/a.mp3'); // what _unmarkAutoAttempt does
      expect(
          DownloadManager.autoDownloadCandidates(q, attempted,
                  fileExists: onDisk)
              .length,
          1);
    });

    test('duplicate copies of one track in the same sweep pick once', () {
      final picked = DownloadManager.autoDownloadCandidates(
          [item('/a.mp3'), item('/a.mp3')], <String>{},
          fileExists: onDisk);
      expect(picked.length, 1);
    });
  });
}
