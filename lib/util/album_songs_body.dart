/// The body of a `/api/v1/db/album-songs` request for an album the user picked
/// from a list.
///
/// Servers since 6.28 collapse an album's per-year fragments into one item and
/// key albums by name + album artist, so two albums that share a name are told
/// apart by the `year` and `album_artist` the list response carried. Both are
/// sent back only when the item has them: never as null, so a server that
/// predates the fields (it ignores unknown keys) sees the request it always did,
/// and never a joined display of several credits (the list gives `album_artist`
/// null when its rows disagree — sending anything then would match nothing).
Map<String, dynamic> albumSongsBody(String? album,
    {int? year, String? albumArtist}) {
  final body = <String, dynamic>{'album': album};
  if (year != null) body['year'] = year;
  final credit = albumArtist?.trim();
  if (credit != null && credit.isNotEmpty) body['album_artist'] = credit;
  return body;
}

/// `year` as the server sends it on an album item: an int, a numeric string,
/// or absent. Anything else is treated as absent.
int? albumYearOf(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

/// `album_artist` as the server sends it on an album item: the group's single
/// credit, or null when the collapsed rows disagree (or on an older server).
String? albumArtistOf(dynamic raw) {
  if (raw is! String) return null;
  final s = raw.trim();
  return s.isEmpty ? null : s;
}
