// Pure A–Z(+deeper) bucketing for the Android Auto browse tree. Kept free of
// Flutter / audio_service deps so it's unit-testable in isolation; the wiring
// (fetch, MediaItem nodes, content style) lives in auto_browse.dart.

/// Max prefix length the deeper bucketing recurses to before bottoming out to
/// leaves (so recursion terminates on degenerate data).
const int autoBucketMaxDepth = 3;

/// Leading articles ignored when bucketing/sorting — the conventional
/// library-sort behaviour, so "The Wall" files under W and "A Night…" under N.
/// Longest first so 'A ' can't pre-empt 'AN '. Only the bucket KEY drops them;
/// the displayed title keeps its article.
const List<String> _articles = ['THE ', 'AN ', 'A '];

/// Uppercased, trimmed, article-stripped sort/bucket key for a display [name].
String autoBucketKey(String name) {
  final k = name.trim().toUpperCase();
  for (final a in _articles) {
    if (k.length > a.length && k.startsWith(a)) return k.substring(a.length);
  }
  return k;
}

final RegExp _letter = RegExp(r'^\p{L}', unicode: true);

/// Top-level bucket label for [name]: its first character (uppercased) when
/// that's a LETTER — any script, so non-Latin names get their own buckets
/// rather than collapsing — otherwise '#', which groups every digit / symbol /
/// empty name together and sorts last.
String autoTopBucket(String name) {
  final k = autoBucketKey(name);
  if (k.isEmpty) return '#';
  final c = k.substring(0, 1);
  return _letter.hasMatch(c) ? c : '#';
}

/// The sorted top-level bucket labels present in [names]: letter buckets in
/// order, then '#' last if any digit/symbol/empty names exist.
List<String> autoTopBuckets(Iterable<String> names) {
  final set = {for (final n in names) autoTopBucket(n)};
  final out = set.where((b) => b != '#').toList()..sort();
  if (set.contains('#')) out.add('#');
  return out;
}

/// One DEEPER bucketing step inside a letter bucket. [keys] are the uppercased
/// names already in this branch; [prefix] is the non-empty letter prefix
/// consumed so far ('S', 'ST', …). Returns the sorted next-level prefixes (each
/// exactly one character longer) when the set overflows [cap], or [] meaning
/// "render the items as leaves" — when they fit, or when [prefix] reached
/// [maxDepth] (so recursion always terminates). Keys equal to [prefix] don't
/// extend and are absent here; the caller renders those as leaves.
List<String> autoBucketPrefixes(Iterable<String> keys, String prefix, int cap,
    {int maxDepth = autoBucketMaxDepth}) {
  final matched = [for (final k in keys) if (k.startsWith(prefix)) k];
  if (matched.length <= cap || prefix.length >= maxDepth) return const [];
  final subs = <String>{};
  for (final k in matched) {
    if (k.length > prefix.length) subs.add(k.substring(0, prefix.length + 1));
  }
  return subs.toList()..sort();
}
