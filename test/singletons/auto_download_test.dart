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

    test('a per-server slot budget picks — and marks — only what fits', () {
      final attempted = <String>{};
      final q = [item('/a'), item('/b'), item('/c'), item('/x', server: 's2')];
      final first = DownloadManager.autoDownloadCandidates(q, attempted,
          fileExists: missing, slotsFor: (s) => s == 's1' ? 1 : 2);
      expect(first.map((m) => m.extras!['path']), ['/a', '/x']);
      expect(attempted, {'s1/a', 's2/x'}, reason: 'the ones left out stay unmarked');
      // The next sweep, with a slot free again, takes the next in order.
      final second = DownloadManager.autoDownloadCandidates(q, attempted,
          fileExists: missing, slotsFor: (s) => s == 's1' ? 1 : 0);
      expect(second.map((m) => m.extras!['path']), ['/b']);
      // No slots → nothing picked, nothing marked.
      expect(DownloadManager.autoDownloadCandidates(q, attempted, fileExists: missing, slotsFor: (_) => 0), isEmpty);
      expect(attempted, {'s1/a', 's2/x', 's1/b'});
    });

    test('already-attempted and on-disk tracks do not consume a slot', () {
      final attempted = {'s1/a'};
      final q = [item('/a'), item('/d', localPath: '/disk/d'), item('/b'), item('/c')];
      final picked = DownloadManager.autoDownloadCandidates(q, attempted,
          fileExists: onDisk, slotsFor: (_) => 1);
      expect(picked.map((m) => m.extras!['path']), ['/b']);
    });

    test('duplicate copies of one track in the same sweep pick once', () {
      final picked = DownloadManager.autoDownloadCandidates(
          [item('/a.mp3'), item('/a.mp3')], <String>{},
          fileExists: onDisk);
      expect(picked.length, 1);
    });
  });
}
