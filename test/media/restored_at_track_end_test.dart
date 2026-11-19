import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.restoredAtTrackEnd', () {
    ({int index, Duration position}) spot(int index, int positionMs) =>
        (index: index, position: Duration(milliseconds: positionMs));
    Duration? length(int? ms) => ms == null ? null : Duration(milliseconds: ms);

    // The snapshot's own spot, loaded: the restore, or the revive that loads
    // it after the restore could not.
    bool atEnd(int positionMs, int? durationMs) =>
        AudioPlayerHandler.restoredAtTrackEnd(
            loaded: spot(1, positionMs),
            snapshot: spot(1, positionMs),
            duration: length(durationMs));

    // The regression this exists for: a snapshot at the end of a track that
    // carries no length gets past the snapshot's own clamp, the load parks
    // there paused, and the first Play completes on the spot and stops
    // (seen on the emulator: restored at 15.050 s of a 15.047 s track).
    test('a saved position past the measured end → at the end', () {
      expect(atEnd(15050, 15047), isTrue);
      expect(atEnd(999999, 15047), isTrue);
    });

    test('exactly at the end → at the end', () {
      expect(atEnd(240000, 240000), isTrue);
    });

    // The same one-second guard the snapshot uses, so a track with its
    // length on it and one without open the same way.
    test('within a second of the end → at the end', () {
      expect(atEnd(239500, 240000), isTrue);
      expect(atEnd(239000, 240000), isTrue);
    });

    test('more than a second before the end is a place to resume', () {
      expect(atEnd(238999, 240000), isFalse);
      expect(atEnd(23000, 240000), isFalse);
    });

    // A stream with no knowable length (a transcode) reports none after the
    // load either. Nothing to judge against, so the saved spot stands.
    test('a length the player could not measure → the saved spot stands', () {
      expect(atEnd(700000, null), isFalse);
      expect(atEnd(700000, 0), isFalse);
    });

    test('a restore at the start has nowhere to go back to', () {
      expect(atEnd(0, 240000), isFalse);
      expect(atEnd(0, null), isFalse);
      // A track shorter than the guard, restored at its start, stays there
      // rather than being "moved" to where it already is.
      expect(atEnd(0, 500), isFalse);
    });

    // Only the snapshot's spot is in doubt. A spot the player really stood
    // on — a stop, or a reload that failed, half a second before a track's
    // end — plays that half second and moves on, as it always has.
    test('a spot the snapshot did not name is left alone', () {
      bool judged(({int index, Duration position})? snapshot) =>
          AudioPlayerHandler.restoredAtTrackEnd(
              loaded: spot(1, 15050),
              snapshot: snapshot,
              duration: length(15047));
      // Once a load has reached ready there is no snapshot spot any more.
      expect(judged(null), isFalse);
      // Another row, or another place in the same row.
      expect(judged(spot(0, 15050)), isFalse);
      expect(judged(spot(1, 14000)), isFalse);
      // The control: the same spot, built separately, is the snapshot's.
      expect(judged(spot(1, 15050)), isTrue);
    });
  });
}
