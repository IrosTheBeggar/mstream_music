import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

HealAction act({
  bool onLocalBackend = true,
  bool intentionalStop = false,
  bool recovering = false,
  bool skipPending = false,
  BackendProcessingState processingState = BackendProcessingState.idle,
  bool queueEmpty = false,
}) =>
    AudioPlayerHandler.healAction(
      onLocalBackend: onLocalBackend,
      intentionalStop: intentionalStop,
      recovering: recovering,
      skipPending: skipPending,
      processingState: processingState,
      queueEmpty: queueEmpty,
    );

void main() {
  group('AudioPlayerHandler.healAction', () {
    test('parked player with tracks queued → run', () {
      expect(act(), HealAction.run);
    });

    // The regression this exists for. The heal's original trigger was a single
    // status edge, and that stream emits on CHANGE only. A player still
    // loading when the edge arrives used to drop it — and if the load then
    // failed, the player parked with the tunnel already connected and no
    // second edge ever coming. Seven and a half minutes of silence in the
    // incident log. Re-arming keeps the trigger alive across that window.
    test('load still in flight → rearm, never drop', () {
      for (final s in [
        BackendProcessingState.loading,
        BackendProcessingState.buffering,
        BackendProcessingState.ready,
      ]) {
        expect(act(processingState: s), HealAction.rearm,
            reason: '$s must keep the trigger alive');
      }
    });

    test('a recovery already in flight → rearm (it will finish)', () {
      expect(act(recovering: true), HealAction.rearm);
      expect(act(skipPending: true), HealAction.rearm);
    });

    test('recovering wins over not-being-parked — both rearm', () {
      expect(
          act(
              recovering: true,
              processingState: BackendProcessingState.loading),
          HealAction.rearm);
    });

    // Dropping is for states no later re-check could rescue: the user stopped
    // deliberately, there is nothing queued, or a renderer owns playback.
    test('deliberate stop → drop', () {
      expect(act(intentionalStop: true), HealAction.drop);
      // Even mid-load, and even while recovering: an intentional stop is the
      // user's decision and must not be undone by a timer.
      expect(
          act(
              intentionalStop: true,
              recovering: true,
              processingState: BackendProcessingState.loading),
          HealAction.drop);
    });

    test('empty queue → drop', () {
      expect(act(queueEmpty: true), HealAction.drop);
      expect(act(queueEmpty: true, recovering: true), HealAction.drop);
    });

    test('casting to a renderer → drop', () {
      expect(act(onLocalBackend: false), HealAction.drop);
      expect(
          act(
              onLocalBackend: false,
              processingState: BackendProcessingState.loading),
          HealAction.drop);
    });
  });
}
