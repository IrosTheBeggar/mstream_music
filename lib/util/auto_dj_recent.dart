import '../objects/play_event.dart';
import 'auto_dj_seeds.dart';
import 'auto_dj_skips.dart' show kQuickSkipMinHeardMs;

/// How many songs the Recently played dropdown offers.
const int kRecentlyPlayedLimit = 20;

/// The songs this phone played most recently on [server] (a
/// [Server.localname]), newest first, each once: what the Auto DJ start
/// prompts offer under Recently played. Only that server's: an opening song
/// must be on the server the DJ runs on, since a path names a row in one
/// library. Only what counted as a play (the app's own rule: half the song or
/// 30 seconds) or ran to its end — not a song stopped or skipped seconds in —
/// and no local file, which has no server. One song is one row whether its
/// path was recorded with the queue's leading slash or without. Pure;
/// unit-tested.
List<TrackFacts> recentlyPlayedOn(Iterable<PlayEvent> events, String server,
        {int limit = kRecentlyPlayedLimit}) =>
    recentlyPlayedIn(events, {server}, limit: limit);

/// [recentlyPlayedOn] over several [servers] (localnames) at once: the Add
/// song sheet's Recently played, where a song from any server of the Auto DJ
/// session can be a seed. Newest first across all of them, from one pass
/// over the events, so the order holds between servers too. The same rules:
/// only what counted as a play or ran to its end, no local file, each song
/// once.
///
/// A song is its [seedKey]: the server with the path in its wire form. The
/// same vpath on two servers is two songs, which a dedupe on the path alone
/// would fold into one, and a path recorded with the queue's leading slash
/// is the same song as one recorded without it. [exclude] holds the keys to
/// leave out: the rows the seed list being added to already has. Pure;
/// unit-tested.
List<TrackFacts> recentlyPlayedIn(
        Iterable<PlayEvent> events, Set<String> servers,
        {int limit = kRecentlyPlayedLimit, Set<String> exclude = const {}}) =>
    _newestIn(events, servers,
        limit: limit,
        exclude: exclude,
        keep: (e) => e.counted || e.outcome == PlayOutcome.completed);

/// The songs skipped lately on [servers] (localnames), newest first, each
/// once: the Less like Add song sheet's Skipped section, after the song
/// playing now. A skip is a play that a change of track ended before it
/// counted ([PlayOutcome.skipped], not [PlayEvent.counted]) once at least
/// [kQuickSkipMinHeardMs] of it was heard. The tracker records a skip for
/// any change of track before the end, the error walk's advance and a row
/// tapped past at once among them, and a song heard for less than that says
/// nothing about the song. Otherwise the rules are [recentlyPlayedIn]'s: no
/// local file, no empty path, a song is its [seedKey], and [exclude] holds
/// the keys to leave out. Pure; unit-tested.
List<TrackFacts> recentlySkippedIn(
        Iterable<PlayEvent> events, Set<String> servers,
        {int limit = kRecentlyPlayedLimit, Set<String> exclude = const {}}) =>
    _newestIn(events, servers,
        limit: limit,
        exclude: exclude,
        keep: (e) =>
            e.outcome == PlayOutcome.skipped &&
            !e.counted &&
            e.playedMs >= kQuickSkipMinHeardMs);

// The songs of the events [keep] takes on [servers], newest first, each once
// by its seedKey, none in [exclude], at most [limit]. A song's newest event
// that [keep] takes is the one that places it.
List<TrackFacts> _newestIn(Iterable<PlayEvent> events, Set<String> servers,
    {required int limit,
    required Set<String> exclude,
    required bool Function(PlayEvent e) keep}) {
  final newest = [...events]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final seen = <String>{};
  final out = <TrackFacts>[];
  for (final e in newest) {
    if (out.length >= limit) break;
    final t = e.track;
    if (t.isLocalFile || !servers.contains(t.server)) continue;
    if (seedWirePath(t.path).isEmpty) continue;
    if (!keep(e)) continue;
    final key = seedKey(t.server, t.path);
    if (exclude.contains(key) || !seen.add(key)) continue;
    out.add(t);
  }
  return out;
}
