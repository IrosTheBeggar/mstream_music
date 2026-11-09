// The Camelot wheel (util/camelot.dart): raw keys to codes, and the six
// codes that mix with one — Harmonic mixing's `musicalKeys`, for Auto DJ's
// anchor and an Instant mix page's seed song. camelotNeighbours used to
// read a second capture group its pattern did not have, and threw on every
// valid code.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/camelot.dart';

void main() {
  test('a raw key to its code; a code passes through; unknown is null', () {
    expect(toCamelotCode('Bb minor'), '3A');
    expect(toCamelotCode('Am'), '8A');
    expect(toCamelotCode('C'), '8B');
    expect(toCamelotCode(' 10A '), '10A');
    expect(toCamelotCode('X'), isNull);
    expect(toCamelotCode(''), isNull);
    expect(toCamelotCode(null), isNull);
  });

  test("a code's neighbours: itself, ±1 on its letter, then the other "
      'letter at the same three numbers', () {
    expect(camelotNeighbours('3A'), ['3A', '2A', '4A', '3B', '2B', '4B']);
    expect(camelotNeighbours('10B'), ['10B', '9B', '11B', '10A', '9A', '11A']);
  });

  test('the wheel wraps at 12 and 1', () {
    expect(camelotNeighbours('12B'), ['12B', '11B', '1B', '12A', '11A', '1A']);
    expect(camelotNeighbours('1A'), ['1A', '12A', '2A', '1B', '12B', '2B']);
  });

  test('anything else comes back alone', () {
    expect(camelotNeighbours('13A'), ['13A']);
    expect(camelotNeighbours('Am'), ['Am']);
  });
}
