/// Which of a connected server's albums an artist copy takes, and what it
/// leaves out — mStream's `src/discovery-plugins/plugins/federation-copy.js`
/// planArtistAlbums, through the webapp's copy (`webapp/alpha/
/// discover-jobs.js` planArtistAlbums, artistLeftOut). Its cases in
/// `test/unit/webapp-discover-jobs.test.mjs` are ported in
/// test/util/plan_artist_albums_test.dart: the copy and the sheet must count
/// the same albums.
///
/// An album is the artist's ("theirs") when its credit IS the artist, or the
/// artist is one of its track artists outside a compilation. An album they
/// only appear on — a compilation, someone else's album with a feature — is
/// left out ('appearance'); with only-missing, so is one the library has by
/// name ('owned'). The singles bucket (the answer's album with no name) is no
/// album: its songs stay out too.
library;

import 'discover_badges.dart' show nameKey;

/// One album of the peer's `artists-albums` answer as the plan reads it.
class PlannedAlbum {
  final String name;
  final int? year;
  final int? trackCount;

  /// A planned album's own credit (the peer's `album_artist`; null when its
  /// rows disagree) — what its songs file under where a file names none.
  final String? albumArtist;

  /// A left-out album's reason: `appearance` or `owned`; null when planned.
  final String? why;

  const PlannedAlbum(this.name,
      {this.year, this.trackCount, this.albumArtist, this.why});

  @override
  bool operator ==(Object other) =>
      other is PlannedAlbum &&
      other.name == name &&
      other.year == year &&
      other.trackCount == trackCount &&
      other.albumArtist == albumArtist &&
      other.why == why;

  @override
  int get hashCode => Object.hash(name, year, trackCount, albumArtist, why);

  @override
  String toString() =>
      'PlannedAlbum($name, $year, $trackCount${albumArtist != null ? ', $albumArtist' : ''}${why != null ? ', $why' : ''})';
}

/// What an artist copy takes ([plan]) and leaves out ([skipped]), and whether
/// the answer had a singles bucket ([singles]).
class ArtistAlbumsPlan {
  final List<PlannedAlbum> plan;
  final List<PlannedAlbum> skipped;
  final bool singles;
  const ArtistAlbumsPlan(
      {this.plan = const [], this.skipped = const [], this.singles = false});

  /// The albums the artist only appears on, by name.
  List<String> get appearances => [
        for (final a in skipped)
          if (a.why == 'appearance') a.name,
      ];
}

/// JS `Number(v)` for the answer's numbers: a finite number, a numeric
/// string, else null (`Number(null)` is 0 — the server checks `== null`
/// first, and so does this).
num? _number(Object? v) {
  if (v is num) return v.isFinite ? v : null;
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return 0;
    final n = num.tryParse(t);
    return n != null && n.isFinite ? n : null;
  }
  if (v is bool) return v ? 1 : 0;
  return null;
}

int? _whole(num? n) => n == null ? null : (n == n.roundToDouble() ? n.toInt() : null);

/// The answer's `albums` ([listing] is the answer — `{albums: […]}` — or
/// the list itself) planned for [artist]. [localKeys] are the library's
/// album names by [nameKey]; [onlyMissing] leaves out the ones it has.
ArtistAlbumsPlan planArtistAlbums(
  Object? listing,
  Object? artist, {
  Set<String> localKeys = const {},
  bool onlyMissing = false,
}) {
  final key = nameKey(artist);
  final rows = listing is Map
      ? (listing['albums'] is List ? listing['albums'] as List : const [])
      : (listing is List ? listing : const []);
  final plan = <PlannedAlbum>[];
  final skipped = <PlannedAlbum>[];
  var singles = false;
  for (final al in rows) {
    if (al is! Map) continue;
    final name = al['name'];
    if (name == null || (name is String && name.trim().isEmpty)) {
      // The bucket of songs in no album (an artists-albums answer's
      // `name: null`; a blank name is one too, as the webapp reads it).
      singles = true;
      continue;
    }
    if (name is! String) continue;
    final y = al['year'];
    final year = y == null ? null : _whole(_number(y));
    final t = al['track_count'];
    final trackCount = t == null ? null : _whole(_number(t));
    final artists = al['artists'];
    final credited =
        artists is List && artists.any((n) => nameKey(n) == key);
    final theirs = nameKey(al['album_artist']) == key ||
        (credited && al['compilation'] != true);
    if (!theirs) {
      skipped.add(PlannedAlbum(name,
          year: year, trackCount: trackCount, why: 'appearance'));
      continue;
    }
    if (onlyMissing && localKeys.contains(nameKey(name))) {
      skipped.add(
          PlannedAlbum(name, year: year, trackCount: trackCount, why: 'owned'));
      continue;
    }
    final credit = al['album_artist'];
    plan.add(PlannedAlbum(
      name,
      year: year,
      trackCount: trackCount,
      albumArtist:
          credit is String && credit.trim().isNotEmpty ? credit : null,
    ));
  }
  return ArtistAlbumsPlan(
    plan: List.unmodifiable(plan),
    skipped: List.unmodifiable(skipped),
    singles: singles,
  );
}

/// The artist copy's left-out line (the sheet's, under Artist): the albums
/// [artist] only appears on — one by name ([one]), several counted ([many])
/// — then, when the answer has a singles bucket, that songs outside an album
/// stay out too ([singles]). Null when nothing is left out, or [listing] is
/// not an answer (it did not come).
class ArtistLeftOut {
  /// The one album left out ([many] 0), else null.
  final String? one;

  /// How many albums are left out when it is more than one, else 0.
  final int many;
  final bool singles;

  /// Their names.
  final List<String> albums;

  const ArtistLeftOut(
      {this.one, this.many = 0, this.singles = false, this.albums = const []});
}

ArtistLeftOut? artistLeftOut(Object? listing, Object? artist) {
  final rows = listing is Map ? listing['albums'] : listing;
  if (rows is! List) return null;
  final p = planArtistAlbums(rows, artist);
  final guest = p.appearances;
  if (guest.isEmpty && !p.singles) return null;
  return ArtistLeftOut(
    one: guest.length == 1 ? guest.first : null,
    many: guest.length > 1 ? guest.length : 0,
    singles: p.singles,
    albums: List.unmodifiable(guest),
  );
}
