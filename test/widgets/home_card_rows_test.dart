// widgets/home_card_rows.dart — the home pairs its cards two by two, and a
// wide card (Peer Recommendations) takes a row of its own (mStream
// docs/peer-recommendations-plan.md §4.2 PH8; the "Way in" board, Home.dc.html
// 50-60: Auto DJ | Sonic path, then Discover, then Peer Recommendations).

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/widgets/home_card_rows.dart';

void main() {
  test('Peer Recommendations is the only wide card', () {
    expect(kWideHomeCards, {'peerRecs'});
  });

  test('the LISTEN group the board draws: a pair, Discover alone, then the '
      'wide card', () {
    expect(homeCardRows(['autoDj', 'sonicPath', 'discover', 'peerRecs']), [
      [0, 1],
      [2],
      [3],
    ]);
  });

  test('no Sonic path: Auto DJ and Discover pair, the wide card alone', () {
    expect(homeCardRows(['autoDj', 'discover', 'peerRecs']), [
      [0, 1],
      [2],
    ]);
  });

  test('no wide card: the odd last card spans, as today', () {
    expect(homeCardRows(['autoDj', 'sonicPath', 'discover']), [
      [0, 1],
      [2],
    ]);
  });

  test('an empty group has no rows', () {
    expect(homeCardRows([]), isEmpty);
  });

  test('a group with no wide card is paired as today', () {
    // The pairing flush() did before: chunks of two, in order.
    List<List<int>> today(int n) => [
          for (var i = 0; i < n; i += 2) [i, if (i + 1 < n) i + 1],
        ];
    for (var n = 1; n <= 7; n++) {
      final slugs = [for (var i = 0; i < n; i++) 'card$i'];
      expect(homeCardRows(slugs), today(n), reason: '$n cards');
    }
    // A card whose DisplayItem.data is null pairs the same.
    expect(homeCardRows([null, 'autoDj', null]), [
      [0, 1],
      [2],
    ]);
  });

  test('a wide card breaks a pair wherever it sits', () {
    expect(homeCardRows(['peerRecs', 'autoDj', 'sonicPath']), [
      [0],
      [1, 2],
    ]);
    expect(homeCardRows(['autoDj', 'peerRecs', 'sonicPath', 'discover']), [
      [0],
      [1],
      [2, 3],
    ]);
    expect(homeCardRows(['peerRecs']), [
      [0],
    ]);
  });
}
