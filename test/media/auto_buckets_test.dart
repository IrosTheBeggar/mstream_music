import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/auto_buckets.dart';

void main() {
  group('autoBucketKey', () {
    test('trims and uppercases', () {
      expect(autoBucketKey('  abbey road '), 'ABBEY ROAD');
      expect(autoBucketKey('Café'), 'CAFÉ');
      expect(autoBucketKey(''), '');
    });
  });

  group('autoBucketPrefixes', () {
    test('a non-root prefix that fits the cap renders as leaves ([])', () {
      expect(autoBucketPrefixes(['ABC', 'ABD'], 'A', 200), isEmpty);
    });

    test('top level groups by first character, sorted and deduped', () {
      final keys = ['APPLE', 'AVON', 'BEE', 'CAR', 'BAT'];
      expect(autoBucketPrefixes(keys, '', 2), ['A', 'B', 'C']);
    });

    test('non-Latin names get their own buckets (no # collapse)', () {
      // Cyrillic А / Я plus Latin C; small cap forces bucketing.
      final out = autoBucketPrefixes(['ЯX', 'АY', 'CZ'], '', 1);
      expect(out.length, 3);
      expect(out, containsAll(['C', 'Я', 'А']));
    });

    test('an overflowing prefix sub-buckets by the next character', () {
      final keys = ['SA1', 'SA2', 'SB1', 'ST1'];
      expect(autoBucketPrefixes(keys, 'S', 2), ['SA', 'SB', 'ST']);
    });

    test('recursion terminates at the depth cap', () {
      // All identical, never splits — must bottom out at maxDepth (3).
      final keys = List.filled(10, 'SAME');
      expect(autoBucketPrefixes(keys, 'SAM', 2), isEmpty);
    });

    test('exact-prefix keys are not emitted as sub-buckets (rendered as leaves)',
        () {
      // 'S' (== prefix) can't extend; 'SX'/'SY'/'SZ' do.
      final out = autoBucketPrefixes(['S', 'SX', 'SY', 'SZ'], 'S', 2);
      expect(out, isNot(contains('S')));
      expect(out, containsAll(['SX', 'SY', 'SZ']));
    });

    test('sub-bucket prefixes are always exactly one char longer than parent',
        () {
      final keys = ['STAR', 'STONE', 'SUN', 'SKY'];
      final out = autoBucketPrefixes(keys, 'S', 1);
      expect(out.every((p) => p.length == 2 && p.startsWith('S')), isTrue);
    });
  });
}
