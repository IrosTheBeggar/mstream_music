// DownloadManager.cacheWindow — the single definition of "what the offline
// cap keeps on disk", read by both the auto-download sweep and the eviction
// pass. Before it existed the cap only evicted tracks that had LEFT the queue,
// so a 100-track queue pulled all 100 files however low the cap was set.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/downloads.dart';

void main() {
  List<MediaItem> queue(int n) => [
        for (var i = 0; i < n; i++) MediaItem(id: 't$i', title: 'Track $i'),
      ];

  List<String> ids(List<MediaItem> items) => [for (final m in items) m.id];

  group('DownloadManager.cacheWindow', () {
    test('cap 0 means unlimited — the whole queue', () {
      expect(ids(DownloadManager.cacheWindow(queue(100), 0, 40)).length, 100);
    });

    test('a negative cap is treated as unlimited too', () {
      expect(ids(DownloadManager.cacheWindow(queue(10), -5, 0)).length, 10);
    });

    // A short queue used to come back whole, so the sweep walked it from the
    // top and fetched the tracks BEHIND the playhead first (2026-10-20: two
    // already-played tracks landed while the one playing streamed).
    test('a queue shorter than the cap still starts at the playing track',
        () {
      expect(ids(DownloadManager.cacheWindow(queue(8), 50, 0)).length, 8);
      expect(ids(DownloadManager.cacheWindow(queue(8), 50, 3)),
          ['t3', 't4', 't5', 't6', 't7']);
    });

    test('caches forward from the playing track, not from the top', () {
      final w = DownloadManager.cacheWindow(queue(100), 3, 40);
      expect(ids(w), ['t40', 't41', 't42']);
    });

    test('the regression: a 100-track queue at cap 50 fetches 50, not 100', () {
      expect(DownloadManager.cacheWindow(queue(100), 50, 0).length, 50);
    });

    test('does not wrap past the end — the tail window is simply shorter', () {
      // Without repeat, tracks before the playing one are behind you.
      final w = DownloadManager.cacheWindow(queue(10), 5, 8);
      expect(ids(w), ['t8', 't9']);
    });

    test('an out-of-range index clamps instead of throwing', () {
      expect(ids(DownloadManager.cacheWindow(queue(10), 2, 99)), ['t9']);
      expect(ids(DownloadManager.cacheWindow(queue(10), 2, -3)), ['t0', 't1']);
    });

    test('window slides as playback advances', () {
      final q = queue(20);
      expect(ids(DownloadManager.cacheWindow(q, 2, 0)), ['t0', 't1']);
      expect(ids(DownloadManager.cacheWindow(q, 2, 1)), ['t1', 't2']);
      expect(ids(DownloadManager.cacheWindow(q, 2, 2)), ['t2', 't3']);
    });

    test('empty queue is safe', () {
      expect(DownloadManager.cacheWindow(const [], 10, 0), isEmpty);
    });
  });

  group('DownloadManager.clippedAhead', () {
    test('counts only tracks ahead of the window, never played ones', () {
      // Galaxy smoke 2026-10-30: an 8-track queue under a cap of 50 logged
      // "1 queued track(s) beyond the cache window" at track 2 — the one
      // behind the playhead.
      expect(DownloadManager.clippedAhead(8, 50, 1), 0);
      expect(DownloadManager.clippedAhead(8, 3, 2), 3); // t5..t7 past t2..t4
      expect(DownloadManager.clippedAhead(8, 3, 5), 0); // t5..t7 fit
    });

    test('clamps the playhead and ignores an unlimited cap', () {
      expect(DownloadManager.clippedAhead(8, 3, -1), 5);
      expect(DownloadManager.clippedAhead(8, 3, 99), 0);
      expect(DownloadManager.clippedAhead(8, 0, 2), 0);
      expect(DownloadManager.clippedAhead(0, 3, 0), 0);
    });
  });
}
