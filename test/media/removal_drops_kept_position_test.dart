import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.removalDropsKeptPosition', () {
    // Defaults are the reported case: a three-track queue that played out,
    // the player stopped on its last row, and that row swiped away.
    bool drops({
      bool onLocalBackend = true,
      BackendProcessingState processingState = BackendProcessingState.idle,
      int? currentIndex = 2,
      int removed = 2,
    }) =>
        AudioPlayerHandler.removalDropsKeptPosition(
            onLocalBackend: onLocalBackend,
            processingState: processingState,
            currentIndex: currentIndex,
            removed: removed);

    // The regression this exists for: the idle player kept the removed
    // track's end as its position, the row left behind showed it and was
    // saved under it (seen on the emulator: an 8-second track at 15.056 s).
    test('the row a stopped player is on → its position goes with it', () {
      expect(drops(), isTrue);
      expect(drops(currentIndex: 0, removed: 0), isTrue);
    });

    // The finished track is still the current row, and its position is
    // still its own: Play after the end decides what to do with it.
    test('another row leaves the position where it is', () {
      expect(drops(removed: 0), isFalse);
      expect(drops(removed: 1), isFalse);
      expect(drops(currentIndex: 0, removed: 2), isFalse);
    });

    // A player with a source loaded moves to the next row by itself and
    // reads its position from that.
    test('a player that is not idle is left to move itself', () {
      for (final state in BackendProcessingState.values) {
        if (state == BackendProcessingState.idle) continue;
        expect(drops(processingState: state), isFalse, reason: state.name);
      }
    });

    test('a cast backend is not ours to seek', () {
      expect(drops(onLocalBackend: false), isFalse);
    });

    test('no current row, nothing to drop', () {
      expect(drops(currentIndex: null), isFalse);
    });
  });
}
