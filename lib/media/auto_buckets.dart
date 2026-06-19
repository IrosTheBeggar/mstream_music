// Pure A–Z(+deeper) bucketing for the Android Auto browse tree. Kept free of
// Flutter / audio_service deps so it's unit-testable in isolation; the wiring
// (fetch, MediaItem nodes, content style) lives in auto_browse.dart.

/// Uppercased, trimmed sort/bucket key for a display [name].
String autoBucketKey(String name) => name.trim().toUpperCase();

/// One bucketing step. Given the bucket [keys] of the items at a node and the
/// [prefix] consumed so far ('' at the tab root, e.g. 'S' / 'ST' on drill-in),
/// returns the sorted next-level prefixes to show as sub-buckets — each exactly
/// one character longer than [prefix].
///
/// Returns an empty list meaning "render the items as leaves": when they
/// already fit under [cap], or when [prefix] reached [maxDepth] (so recursion
/// always terminates). Items whose key doesn't extend past [prefix] (key ==
/// prefix) are intentionally absent from the result — the caller renders those
/// as leaves alongside the sub-buckets. Buckets by the real first character(s),
/// so non-Latin names get their own buckets rather than collapsing together.
List<String> autoBucketPrefixes(Iterable<String> keys, String prefix, int cap,
    {int maxDepth = 3}) {
  final matched = prefix.isEmpty
      ? keys.toList()
      : [for (final k in keys) if (k.startsWith(prefix)) k];
  if (prefix.isNotEmpty && matched.length <= cap) return const [];
  if (prefix.length >= maxDepth) return const [];
  final subs = <String>{};
  for (final k in matched) {
    if (k.length > prefix.length) subs.add(k.substring(0, prefix.length + 1));
  }
  return subs.toList()..sort();
}
