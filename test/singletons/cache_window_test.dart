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

    test('a queue shorter than the cap is returned whole', () {
      expect(ids(DownloadManager.cacheWindow(queue(8), 50, 0)).length, 8);
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
}
