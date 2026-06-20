import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/auto_buckets.dart';

void main() {
  group('autoBucketKey', () {
    test('trims and uppercases', () {
      expect(autoBucketKey('  abbey road '), 'ABBEY ROAD');
      expect(autoBucketKey('Café'), 'CAFÉ');
      expect(autoBucketKey(''), '');
    });
    test('strips a leading article (The/A/An), keeping the rest', () {
      expect(autoBucketKey('The Wall'), 'WALL');
      expect(autoBucketKey('an evening with'), 'EVENING WITH');
      expect(autoBucketKey('A Night at the Opera'), 'NIGHT AT THE OPERA');
    });
    test('does not strip an article that is not a separate leading word', () {
      expect(autoBucketKey('Theory of a Deadman'), 'THEORY OF A DEADMAN');
      expect(autoBucketKey('Abbey Road'), 'ABBEY ROAD');
      expect(autoBucketKey('Anthrax'), 'ANTHRAX');
      expect(autoBucketKey('The'), 'THE'); // nothing after the article
    });
  });

  group('autoTopBucket', () {
    test('a leading letter is its own (uppercased) bucket', () {
      expect(autoTopBucket('abbey road'), 'A');
      expect(autoTopBucket('  Zeppelin'), 'Z');
    });
    test('files past a leading article', () {
      expect(autoTopBucket('The Beatles'), 'B');
      expect(autoTopBucket('The Wall'), 'W');
      expect(autoTopBucket('A Hard Day\'s Night'), 'H');
    });
    test('non-Latin letters get their own bucket (not collapsed)', () {
      expect(autoTopBucket('Ярость'), 'Я');
      expect(autoTopBucket('名前'), '名');
    });
    test('digits, symbols and empty all map to #', () {
      expect(autoTopBucket('2Pac'), '#');
      expect(autoTopBucket('99 Luftballons'), '#');
      expect(autoTopBucket('!!!'), '#');
      expect(autoTopBucket(''), '#');
      expect(autoTopBucket('   '), '#');
    });
  });

  group('autoTopBuckets', () {
    test('letters sorted, # last, deduped', () {
      final names = ['Apple', '2 Unlimited', 'Beta', '99', 'Zoo', 'amber'];
      expect(autoTopBuckets(names), ['A', 'B', 'Z', '#']);
    });
    test('no # when every name starts with a letter', () {
      expect(autoTopBuckets(['Apple', 'Ярость', '名前']), ['A', 'Я', '名']);
    });
  });

  group('autoBucketPrefixes (deeper drill-in)', () {
    test('fits under the cap → render as leaves ([])', () {
      expect(autoBucketPrefixes(['SUN', 'SKY'], 'S', 200), isEmpty);
    });
    test('an overflowing prefix sub-buckets by the next character', () {
      final keys = ['SA1', 'SA2', 'SB1', 'ST1'];
      expect(autoBucketPrefixes(keys, 'S', 2), ['SA', 'SB', 'ST']);
    });
    test('sub-bucket prefixes are exactly one char longer than the parent', () {
      final out = autoBucketPrefixes(['STAR', 'STONE', 'SUN', 'SKY'], 'S', 1);
      expect(out.every((p) => p.length == 2 && p.startsWith('S')), isTrue);
    });
    test('recursion terminates at the depth cap', () {
      expect(autoBucketPrefixes(List.filled(10, 'SAME'), 'SAM', 2), isEmpty);
    });
    test('exact-prefix keys are not emitted as sub-buckets', () {
      final out = autoBucketPrefixes(['S', 'SX', 'SY', 'SZ'], 'S', 2);
      expect(out, isNot(contains('S')));
      expect(out, containsAll(['SX', 'SY', 'SZ']));
    });
  });
}
