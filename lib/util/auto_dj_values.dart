// The Auto DJ screen's values, before they meet a language: track-length
// bounds, half-star ratings, and whether every server agrees on a setting
// (the All servers rows say "Varies" when they don't). Pure; unit-tested.

/// m:ss for a track-length bound, h:mm:ss from an hour up.
String fmtTrackLength(int seconds) {
  final h = seconds ~/ 3600;
  final m = seconds % 3600 ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// A minimum rating on the server's half-star 1–10 scale, in stars: 7 is
/// "3.5", 8 is "4".
String fmtStars(int rating) =>
    rating.isEven ? '${rating ~/ 2}' : (rating / 2).toStringAsFixed(1);

/// True when every one of [values] is the same (or there are none).
bool allSame<T>(Iterable<T> values) {
  final it = values.iterator;
  if (!it.moveNext()) return true;
  final first = it.current;
  while (it.moveNext()) {
    if (it.current != first) return false;
  }
  return true;
}
