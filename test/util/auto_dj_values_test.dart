// The Auto DJ screen's values before they meet a language
// (util/auto_dj_values.dart): track-length bounds as m:ss, the server's
// half-star 1–10 minimum rating in stars, and whether every server agrees on
// a setting (the All servers rows say "Varies" when they don't).

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/auto_dj_values.dart';

void main() {
  group('fmtTrackLength', () {
    test('minutes and zero-padded seconds', () {
      expect(fmtTrackLength(0), '0:00');
      expect(fmtTrackLength(5), '0:05');
      expect(fmtTrackLength(59), '0:59');
      expect(fmtTrackLength(60), '1:00');
      expect(fmtTrackLength(75), '1:15');
      expect(fmtTrackLength(120), '2:00');
      expect(fmtTrackLength(605), '10:05');
    });

    test('an hour and up is h:mm:ss', () {
      expect(fmtTrackLength(3599), '59:59');
      expect(fmtTrackLength(3600), '1:00:00');
      expect(fmtTrackLength(3661), '1:01:01');
      expect(fmtTrackLength(3930), '1:05:30');
      // The Length sheet's timer wheels top out here.
      expect(fmtTrackLength(86399), '23:59:59');
    });
  });

  group('fmtStars', () {
    test('an even rating is whole stars', () {
      expect(fmtStars(2), '1');
      expect(fmtStars(6), '3');
      expect(fmtStars(8), '4');
      expect(fmtStars(10), '5');
    });

    test('an odd rating is a half star, one decimal', () {
      expect(fmtStars(1), '0.5');
      expect(fmtStars(3), '1.5');
      expect(fmtStars(7), '3.5');
      expect(fmtStars(9), '4.5');
    });

    test('every value on the scale reads as rating / 2', () {
      for (var r = 1; r <= 10; r++) {
        expect(double.parse(fmtStars(r)), r / 2, reason: '$r');
      }
    });
  });

  group('allSame', () {
    test('none, or one, agree', () {
      expect(allSame(const <int>[]), isTrue);
      expect(allSame(const [4]), isTrue);
    });

    test('equal values agree, any difference does not', () {
      expect(allSame(const [4, 4, 4]), isTrue);
      expect(allSame(const [4, 4, 5]), isFalse);
      expect(allSame(const [5, 4, 4]), isFalse);
      expect(allSame(const ['a', 'a']), isTrue);
      expect(allSame(const ['a', 'A']), isFalse, reason: 'case matters');
    });

    test('nulls compare like any value (a rating left unset)', () {
      expect(allSame(const <int?>[null, null]), isTrue);
      expect(allSame(const <int?>[null, 6]), isFalse);
      expect(allSame(const <int?>[6, null]), isFalse);
    });

    test('takes any iterable, lazily', () {
      expect(allSame({1}), isTrue);
      expect(allSame([1, 1, 1].map((v) => v * 2)), isTrue);
      var visited = 0;
      final lazy = [1, 2, 3, 4].map((v) {
        visited++;
        return v;
      });
      expect(allSame(lazy), isFalse);
      expect(visited, 2, reason: 'stops at the first difference');
    });
  });
}
