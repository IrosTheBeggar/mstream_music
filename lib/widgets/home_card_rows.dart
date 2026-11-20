// How a home group's cards sit in rows (mStream
// docs/peer-recommendations-plan.md §4.2 PH8). The home pairs its cards two
// by two; a wide card takes a row of its own, so the LISTEN group reads
// [Auto DJ | Sonic path], then Discover, then Peer Recommendations, as the
// "Way in" board draws it.

/// The cards that always take a whole row, by their DisplayItem.data slug.
const Set<String> kWideHomeCards = {'peerRecs'};

/// The rows a home group's cards sit in, as indices into [slugs] (each card's
/// DisplayItem.data). Cards pair up in order, and a wide card takes a row of
/// its own, so the card before it may end up alone (it spans the row). A
/// group with no wide card pairs exactly as the home always has, an odd last
/// card on its own.
List<List<int>> homeCardRows(List<String?> slugs) {
  final rows = <List<int>>[];
  var pair = <int>[];
  for (var i = 0; i < slugs.length; i++) {
    if (kWideHomeCards.contains(slugs[i])) {
      if (pair.isNotEmpty) {
        rows.add(pair);
        pair = <int>[];
      }
      rows.add([i]);
    } else {
      pair.add(i);
      if (pair.length == 2) {
        rows.add(pair);
        pair = <int>[];
      }
    }
  }
  if (pair.isNotEmpty) rows.add(pair);
  return rows;
}
