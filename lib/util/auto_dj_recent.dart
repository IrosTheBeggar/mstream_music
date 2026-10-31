import '../objects/play_event.dart';

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
    {int limit = kRecentlyPlayedLimit}) {
  final newest = [...events]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final seen = <String>{};
  final out = <TrackFacts>[];
  for (final e in newest) {
    final t = e.track;
    if (t.server != server || t.path.isEmpty) continue;
    if (!e.counted && e.outcome != PlayOutcome.completed) continue;
    final key = t.path.startsWith('/') ? t.path.substring(1) : t.path;
    if (!seen.add(key)) continue;
    out.add(t);
    if (out.length >= limit) break;
  }
  return out;
}
