import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/auto_download_entry.dart';
import 'package:mstream_music/singletons/auto_download_ledger.dart';

void main() {
  // Oldest-first list (newest appended), mirroring the ledger's storage order.
  List<AutoDownloadEntry> entries(int n) => [
        for (var i = 0; i < n; i++) AutoDownloadEntry('s', '/t$i.mp3', '/dl/t$i.mp3'),
      ];

  bool protectNone(String s, String p) => false;

  group('AutoDownloadLedger.selectEvictions', () {
    test('cap 0 keeps everything (unlimited)', () {
      final picked = AutoDownloadLedger.selectEvictions(entries(100), 0,
          isProtected: protectNone);
      expect(picked, isEmpty);
    });

    test('under and at the cap evict nothing', () {
      expect(
          AutoDownloadLedger.selectEvictions(entries(3), 5,
              isProtected: protectNone),
          isEmpty);
      expect(
          AutoDownloadLedger.selectEvictions(entries(5), 5,
              isProtected: protectNone),
          isEmpty);
    });

    test('over the cap evicts the oldest first, exactly enough', () {
      final picked = AutoDownloadLedger.selectEvictions(entries(8), 5,
          isProtected: protectNone);
      expect(picked.length, 3);
      // Oldest three (t0, t1, t2) go; t3..t7 stay.
      expect(picked.map((e) => e.path), ['/t0.mp3', '/t1.mp3', '/t2.mp3']);
    });

    test('protected (in-queue) entries are never evicted, even past the cap',
        () {
      // t0 and t1 are the oldest but sit in the queue: eviction must skip them
      // and take the next-oldest unprotected ones instead.
      final protectedKeys = {'s/t0.mp3', 's/t1.mp3'};
      final picked = AutoDownloadLedger.selectEvictions(entries(8), 5,
          isProtected: (s, p) => protectedKeys.contains(s + p));
      expect(picked.length, 3);
      expect(picked.map((e) => e.path), ['/t2.mp3', '/t3.mp3', '/t4.mp3']);
    });

    test('leaves total above cap when too many are protected', () {
      // 6 entries, cap 3, but 5 are protected — only 1 is evictable, so the
      // total can only drop to 5. The queue stays fully offline-available.
      final protectedKeys = {
        's/t0.mp3',
        's/t1.mp3',
        's/t2.mp3',
        's/t3.mp3',
        's/t4.mp3'
      };
      final picked = AutoDownloadLedger.selectEvictions(entries(6), 3,
          isProtected: (s, p) => protectedKeys.contains(s + p));
      expect(picked.map((e) => e.path), ['/t5.mp3']);
    });
  });
}
