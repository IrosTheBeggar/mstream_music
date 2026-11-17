// Quick skips and the re-roll they can ask for (design E): which Next is a
// quick skip of an Auto DJ pick, when a skip moves forward through the queue
// and when it counts once its song's vector is back, which queued DJ rows a
// re-roll may replace and which of them it takes out as it lands, and how
// many of its songs it then queues.
//
// The rules live here, away from the handler, because AudioPlayerHandler is
// never built in tests and most of lib/ is one import cycle with it. This
// file imports only audio_service, the play threshold and the seed keys, so
// its test runs on plain values while the rest of the app is mid-edit.

import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/play_event.dart';
import 'auto_dj_seeds.dart' show seedKey;

/// How long a song must have been heard before a Next says anything about
/// it: one pressed within the first second is a mis-tap, or one press of a
/// run through the queue, not a verdict on the song.
const int kQuickSkipMinHeardMs = 1000;

/// Whether a Next is a quick skip of an Auto DJ pick: the row is one the DJ
/// queued ([djPick]; the handler passes true as well for the user's own
/// song that the lane's start blended into More like, quickSkipsBlend in
/// util/auto_dj_wire.dart); it was heard ([heardMs]) for at least
/// [kQuickSkipMinHeardMs], but not long enough to count as a play
/// ([countsAsPlay], the server's own rule, over [durationMs] when it is
/// known); and the Next really moves to another row ([hasNext], in play
/// order). Without that last test a Next that only restarts the row (the
/// phone's player under repeat-one) or does nothing at all (the end of a
/// queue that doesn't repeat) would count against a song still playing.
/// Pure; unit-tested.
bool isQuickSkip(
        {required bool djPick,
        required int heardMs,
        int? durationMs,
        required bool hasNext}) =>
    djPick &&
    hasNext &&
    heardMs >= kQuickSkipMinHeardMs &&
    !countsAsPlay(playedMs: heardMs, durationMs: durationMs);

/// Whether a Next from row [index] of a queue of [queueLength] moves forward
/// in queue order, so that the rows after the one it lands on are the rows
/// still to play: not under [shuffle], where play order is not queue order,
/// and not from the last row, where repeat-all wraps to the top and every
/// row after the new current one has played already. Only such a skip
/// re-rolls the picks ahead. Pure; unit-tested.
bool skipMovesForward(
        {required int? index, required int queueLength, required bool shuffle}) =>
    !shuffle && index != null && index >= 0 && index < queueLength - 1;

/// The rows of [queue] a re-roll may replace, as indices in ascending order,
/// so nearest first: the DJ's picks (extras `djPick`) strictly after
/// [current]. Never the current row, which is playing, and never a row the
/// user queued. Never a pick whose file is on the phone ([onDisk]), which
/// plays with no network at all, or on its way there ([inFlight], by the
/// row's server and path), whose transfer would run on for a song no longer
/// queued, there being no cancel for one transfer. Nothing under [shuffle],
/// where the rows after the current one in the queue are not the ones that
/// play next. Pure; unit-tested.
List<int> rerollDroppable(List<MediaItem> queue, int current,
    {required bool Function(MediaItem) onDisk,
    required bool Function(String server, String path) inFlight,
    required bool shuffle}) {
  if (shuffle) return const [];
  final out = <int>[];
  for (var i = current < 0 ? 0 : current + 1; i < queue.length; i++) {
    final m = queue[i];
    final extras = m.extras;
    if (extras?['djPick'] != true || onDisk(m)) continue;
    final server = extras?['server'];
    final path = extras?['path'];
    if (server is String && path is String && inFlight(server, path)) continue;
    out.add(i);
  }
  return out;
}

/// A queue row's identity for the re-roll: its server's localname and its
/// path, as a [seedKey]. A URL rebuild (a tunnel's new port, a token
/// refresh, a transcode change) gives a row a new id and a new MediaItem,
/// but never another song. Null for a row with no server or path (a local
/// file), which a re-roll never replaces. Pure; unit-tested.
String? rerollKey(MediaItem m) {
  final server = m.extras?['server'];
  final path = m.extras?['path'];
  return server is String && path is String ? seedKey(server, path) : null;
}

/// The stale picks a learned skip's re-roll is there to replace: the keys
/// ([rerollKey]) of the rows at [droppable] in [queue], which
/// [rerollDroppable] gives for the row the skip landed on. Taken when the
/// re-roll starts, since by the time it lands the user may have gone back to
/// a row the skip left behind, and the DJ rows after that one are songs
/// already played (the skipped one among them), not the stale picks.
/// Pure; unit-tested.
Set<String> rerollStaleKeys(List<MediaItem> queue, List<int> droppable) => {
      for (final i in droppable)
        if (i >= 0 && i < queue.length) ?rerollKey(queue[i]),
    };

/// Which rows a landing re-roll of [picks] songs takes out: of [droppable]
/// ([rerollDroppable]'s indices into [queue] for the row playing as it
/// lands), the nearest first, at most [picks] of them, and only the stale
/// picks the skip named ([stale], [rerollStaleKeys]) when it named them.
/// Chosen when the drop runs, never earlier: a rebuild that ran first has
/// swapped every row for a new one, and the rows are told by their songs.
/// Pure; unit-tested.
List<int> rerollDrops(List<MediaItem> queue, List<int> droppable,
        {required int picks, Set<String>? stale}) =>
    [
      for (final i in droppable)
        if (i >= 0 &&
            i < queue.length &&
            (stale == null || stale.contains(rerollKey(queue[i]))))
          i,
    ].take(picks < 0 ? 0 : picks).toList();

/// Whether a quick skip that was not learned when it was judged is learned
/// once its song's vector has come back: the Next moved [forward], in the
/// same lane ([sameLane]), and the vector now reaches a server the next pick
/// asks ([sentNow]) where it did not before the skip ([sentBefore]). A song
/// already in Less like whose cached vector those servers were being sent
/// is no news to them, so its re-skip re-rolls nothing. Pure; unit-tested.
bool learnedOnceVectorLands(
        {required bool learned,
        required bool forward,
        required bool sameLane,
        required bool sentBefore,
        required bool sentNow}) =>
    !learned && forward && sameLane && !sentBefore && sentNow;

/// How many of a landing re-roll's [picks] songs to queue once [dropped] of
/// the stale picks ahead were taken out: one for each, so the run of songs
/// ahead keeps its length, and every one when the current row is now the
/// last ([atEnd]), where the queue needs a whole batch as at any top-up.
/// None when nothing could go and rows still lie ahead: those rows are the
/// user's own, on the phone or on their way there, and they play first.
/// Pure; unit-tested.
int rerollQueueCount(
        {required int picks, required int dropped, required bool atEnd}) =>
    atEnd ? picks : (dropped < picks ? dropped : picks);

/// Whether an Auto DJ call that just finished runs once more: a learned
/// quick skip moved the queue's generation while it was out ([gen] is the
/// generation now, [genAtEntry] the one it started under), so its pick was
/// thrown away as stale, or landed just before, and the re-roll the skip
/// asked for is still owed ([rerolledGen] is behind [gen]). Not when the
/// lane changed meanwhile ([sameLane] false: a clear, a server switch or
/// the DJ off owe nothing), with the DJ off ([armed]), or for a pick that
/// was deferred or failed ([pickPending]), which the tunnel's return or the
/// next top-up retries and lands as the re-roll. It can't loop: a run that
/// settles the re-roll owes nothing, and one only runs again when another
/// learned skip came while it was out. Pure; unit-tested.
bool shouldRerunPick(
        {required int genAtEntry,
        required int gen,
        required int rerolledGen,
        required bool sameLane,
        required bool armed,
        required bool pickPending}) =>
    gen != genAtEntry && sameLane && armed && !pickPending && rerolledGen < gen;
