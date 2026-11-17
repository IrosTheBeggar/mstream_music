import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:mstream_music/media/local_playback_backend.dart';

// The phone player's answer to "would a Next leave this row?"
// (PlaybackBackend.hasNext), which the Auto DJ reads before it judges a
// quick skip: a Next that does not move must never count against the song
// still playing. just_audio's seekToNext goes to its next index, which is
// the current one under LoopMode.one, and its seek returns without doing
// anything while the player is loading (just_audio 0.10.6 AudioPlayer.seek),
// as it is during a reload of the queue at the playing spot.
void main() {
  group('LocalPlaybackBackend.advancesOnNext', () {
    test('a next row in play order: the Next moves', () {
      for (final state in [
        ProcessingState.idle,
        ProcessingState.buffering,
        ProcessingState.ready,
        ProcessingState.completed,
      ]) {
        expect(
            LocalPlaybackBackend.advancesOnNext(
                nextIndex: 2, currentIndex: 1, state: state),
            isTrue,
            reason: '$state');
      }
    });

    test('while the player loads, the Next is dropped', () {
      // A reload at the spot: the index is already the row being reloaded.
      expect(
          LocalPlaybackBackend.advancesOnNext(
              nextIndex: 2, currentIndex: 1, state: ProcessingState.loading),
          isFalse);
    });

    test('no next row, or the current one again (repeat-one), stays put', () {
      expect(
          LocalPlaybackBackend.advancesOnNext(
              nextIndex: null, currentIndex: 3, state: ProcessingState.ready),
          isFalse);
      expect(
          LocalPlaybackBackend.advancesOnNext(
              nextIndex: 1, currentIndex: 1, state: ProcessingState.ready),
          isFalse);
    });

    test('shuffle order is the player\'s: a next index before the current '
        'row still moves', () {
      expect(
          LocalPlaybackBackend.advancesOnNext(
              nextIndex: 0, currentIndex: 4, state: ProcessingState.ready),
          isTrue);
    });
  });
}
