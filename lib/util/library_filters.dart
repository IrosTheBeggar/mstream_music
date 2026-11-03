// library_filters.dart — the song filters that describe the LIBRARY rather
// than a session, as random-songs' keys: excluded folders, a minimum
// rating, genres, a track-length window and a mood. mStream's Instant mix
// route (POST /api/v1/discovery/local/mix) takes the same keys with the
// same schemas.
//
// One builder for both callers, so the same choices go out the same way:
// Auto DJ sends its own (AutoDJManager.libraryFilters, on every pick and on
// the "Surprise me" opener), an Instant mix page the ones set on it
// (MixFilters.toRequest). Pure; each key is sent only while it filters.

import '../objects/genre_source.dart';
import '../objects/mood_filter.dart';
import '../objects/server.dart';

/// The library filters for a request to [server]: [ignoreVPaths] (the
/// folders switched off), [minRating] (1–10, half stars), [genres] matched
/// by [genreMode] ('whitelist' | 'blacklist') among [genreSource]'s links,
/// the [duration] window in seconds (a null side is no bound; null is no
/// window) with [allowUnknownDuration], and [mood].
Map<String, dynamic> libraryFilterFields(
  Server server, {
  Iterable<String> ignoreVPaths = const [],
  int? minRating,
  List<String> genres = const [],
  String genreMode = 'whitelist',
  GenreSource genreSource = GenreSource.both,
  ({int? min, int? max})? duration,
  bool allowUnknownDuration = false,
  MoodFilter? mood,
}) {
  final out = <String, dynamic>{};
  final off = ignoreVPaths.toList();
  if (off.isNotEmpty) out['ignoreVPaths'] = off;
  // Ratings are per-user; a peer is reached with a key (or a guest token)
  // that has none, and the server skips the clause for such a caller.
  if (minRating != null && !server.isFederated) out['minRating'] = minRating;
  // An empty list constrains nothing, whatever the mode.
  if (genres.isNotEmpty) {
    out['genres'] = genres;
    out['genreMode'] = genreMode;
    final source = genreSource.apiValue;
    if (source != null) out['genreSource'] = source;
  }
  // allowUnknownDuration only beside a bound: the server no-ops it without
  // a window to apply it to.
  if (duration != null) {
    if (duration.min != null) out['minDuration'] = duration.min;
    if (duration.max != null) out['maxDuration'] = duration.max;
    if (allowUnknownDuration) out['allowUnknownDuration'] = true;
  }
  // Only to a server that says it can filter by mood: the routes refuse an
  // unknown key, and the flag is off for a peer, whose flags the app cannot
  // read (the rule Rated, Recent and Discover follow too).
  if (mood != null && !mood.isEmpty && server.moodFiltersAvailable == true) {
    out['moods'] = mood.toJson();
  }
  return out;
}
