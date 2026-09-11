import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/play_tracker.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 4, 19, 0);
  const track = TrackFacts(
      server: 'home',
      path: '/music/a.flac',
      title: 'A',
      durationMs: 200000);

  // The handler's key: server localname + NUL + path.
  final key = 'home${String.fromCharCode(0)}/music/a.flac';
  PlaySession open({TrackFacts facts = track, bool playing = true}) =>
      PlaySession(
          key: key,
          track: facts,
          startedAt: t0,
          source: PlaySource.manual,
          playing: playing);

  // Feed [samples] as (seconds of wall clock, position ms) pairs.
  PlaySession feed(PlaySession s, List<(int, int)> samples) {
    for (final (wallS, posMs) in samples) {
      final r = PlaySessionFold.onPosition(
          s, Duration(milliseconds: posMs), t0.add(Duration(seconds: wallS)));
      expect(r.restarted, isFalse);
      s = r.session;
    }
    return s;
  }

  group('PlaySessionFold.onPosition', () {
    test('steady playback accumulates the position deltas', () {
      final s = feed(open(), [(0, 0), (1, 1000), (2, 2000), (3, 3050)]);
      expect(s.playedMs, 3050);
    });

    test('a seek jump is not listening; playback after it is', () {
      final s = feed(open(), [(0, 0), (1, 1000), (2, 60000), (3, 61000)]);
      expect(s.playedMs, 2000);
    });

    test('a stall and a backwards jump contribute nothing', () {
      final s = feed(open(), [(0, 5000), (2, 5000), (3, 5000), (4, 1000), (5, 2000)]);
      expect(s.playedMs, 1000);
    });

    test('nothing accrues while paused, and a pause counts once', () {
      var s = feed(open(), [(0, 0), (1, 1000)]);
      s = PlaySessionFold.onPlaying(s, false);
      s = PlaySessionFold.onPlaying(s, false); // repeated state, no double count
      s = feed(s, [(2, 1000), (30, 1000)]);
      s = PlaySessionFold.onPlaying(s, true);
      s = feed(s, [(31, 1000), (32, 2000)]);
      expect(s.playedMs, 2000);
      expect(s.pauseCount, 1);
    });

    test('a pending seek swallows exactly the next delta', () {
      var s = feed(open(), [(0, 0), (1, 1000)]);
      s = PlaySessionFold.onSeek(s);
      s = feed(s, [(2, 1500), (3, 2500)]); // 1000 to 1500 was the seek landing
      expect(s.playedMs, 2000);
      expect(s.seekPending, isFalse);
    });

    test('the same track starting over after its end is a restart, not a seek', () {
      var s = feed(open(), [(0, 190000), (9, 199000)]);
      final r = PlaySessionFold.onPosition(
          s, const Duration(milliseconds: 200), t0.add(const Duration(seconds: 10)));
      expect(r.restarted, isTrue);
      // A scrub back to the start from the end is a seek, not a restart.
      s = PlaySessionFold.onSeek(feed(open(), [(0, 190000), (9, 199000)]));
      final r2 = PlaySessionFold.onPosition(
          s, const Duration(milliseconds: 200), t0.add(const Duration(seconds: 10)));
      expect(r2.restarted, isFalse);
      // Without a known duration there is no "end", so no restart either.
      final noDur = feed(open(facts: track.withDuration(null)), [(0, 190000), (9, 199000)]);
      final r3 = PlaySessionFold.onPosition(
          noDur, Duration.zero, t0.add(const Duration(seconds: 10)));
      expect(r3.restarted, isFalse);
    });
  });

  group('PlaySessionFold.close', () {
    test('a track change near the end is completed; earlier is skipped', () {
      final atEnd = feed(open(), [(0, 0), (198, 198500)]);
      expect(PlaySessionFold.outcomeFor(atEnd, PlayCloseReason.trackChanged),
          PlayOutcome.completed);
      final mid = feed(open(), [(0, 0), (60, 60000)]);
      expect(PlaySessionFold.outcomeFor(mid, PlayCloseReason.trackChanged),
          PlayOutcome.skipped);
      expect(PlaySessionFold.outcomeFor(mid, PlayCloseReason.queueEnd),
          PlayOutcome.completed);
      expect(PlaySessionFold.outcomeFor(mid, PlayCloseReason.stopped),
          PlayOutcome.stopped);
      expect(PlaySessionFold.outcomeFor(mid, PlayCloseReason.recovered),
          PlayOutcome.stopped);
    });

    test('the event carries the session and the local counting verdict', () {
      final s = feed(open(), [(0, 0), (45, 45000)]);
      final e = PlaySessionFold.close(
          s, PlayCloseReason.trackChanged, t0.add(const Duration(seconds: 46)),
          id: 'ev1');
      expect(e.id, 'ev1');
      expect(e.startedAt, t0);
      expect(e.endedAt, t0.add(const Duration(seconds: 46)));
      expect(e.playedMs, 45000);
      expect(e.outcome, PlayOutcome.skipped);
      expect(e.counted, isTrue);
      expect(e.track.title, 'A');
      final short = feed(open(), [(0, 0), (10, 10000)]);
      expect(PlaySessionFold.close(short, PlayCloseReason.trackChanged, t0, id: 'x').counted,
          isFalse);
    });

    test('a duration learned mid-session updates the track facts', () {
      final s = PlaySessionFold.onDuration(open(facts: track.withDuration(null)), 180000);
      expect(s.track.durationMs, 180000);
      expect(identical(PlaySessionFold.onDuration(s, 180000), s), isTrue);
      expect(identical(PlaySessionFold.onDuration(s, null), s), isTrue);
    });
  });

  group('checkpoint', () {
    test('a checkpointed session recovers as a stopped event at the checkpoint time', () {
      final s = feed(open(), [(0, 0), (40, 40000)]);
      final at = t0.add(const Duration(seconds: 41));
      final e = PlaySessionFold.recover(s.toCheckpoint(at), id: 'rec');
      expect(e, isNotNull);
      expect(e!.outcome, PlayOutcome.stopped);
      expect(e.startedAt, t0);
      expect(e.endedAt, at);
      expect(e.playedMs, 40000);
      expect(e.counted, isTrue);
      expect(e.source, PlaySource.manual);
      expect(e.track.path, '/music/a.flac');
      expect(e.track.durationMs, 200000);
    });

    test('an incomplete checkpoint recovers nothing', () {
      expect(PlaySessionFold.recover({'t': 1}, id: 'x'), isNull);
      expect(PlaySessionFold.recover({'t': 1, 'pl': 2}, id: 'x'), isNull); // no track
    });
  });
}
