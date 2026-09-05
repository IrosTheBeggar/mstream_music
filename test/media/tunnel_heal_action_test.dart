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
  bool healSuspended = false,
}) =>
    AudioPlayerHandler.healAction(
      onLocalBackend: onLocalBackend,
      intentionalStop: intentionalStop,
      recovering: recovering,
      skipPending: skipPending,
      processingState: processingState,
      queueEmpty: queueEmpty,
      healSuspended: healSuspended,
    );

void main() {
  group('AudioPlayerHandler.healAction', () {
    test('parked player with tracks queued → run', () {
      expect(act(), HealAction.run);
    });

    // After a hand-off the skip walk owns the failures: every park during it
    // used to re-trigger the heal (the idle transition is its own trigger),
    // re-seeding each failing track twice more before the probe handed it
    // off again — ~35 s per track instead of ~3 s.
    test('suspended after a hand-off → drop, even when parked', () {
      expect(act(healSuspended: true), HealAction.drop);
      expect(act(healSuspended: true, processingState: BackendProcessingState.loading), HealAction.drop);
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

  group('AudioPlayerHandler.healResumeFailureAction', () {
    ResumeFailureAction act({bool pathVerified = false, int failures = 1}) =>
        AudioPlayerHandler.healResumeFailureAction(
            pathVerified: pathVerified, failures: failures);

    test('a resume that failed with no verdict yet → rearm', () {
      expect(act(), ResumeFailureAction.rearm);
      expect(act(failures: 2), ResumeFailureAction.rearm);
    });

    // The loop this exists for: an expired guest token (or a rotated secret)
    // made every load fail against a tunnel that was perfectly fine, the
    // probe said so, and the heal re-seeded the same track every ~14s anyway.
    test('the probe cleared the path → the track takes the skip walk', () {
      expect(act(pathVerified: true), ResumeFailureAction.skipTrack);
      expect(act(pathVerified: true, failures: 1), ResumeFailureAction.skipTrack);
    });

    test('with no verdict, the bound alone ends it', () {
      expect(act(failures: AudioPlayerHandler.kMaxHealResumeFailures - 1), ResumeFailureAction.rearm);
      expect(act(failures: AudioPlayerHandler.kMaxHealResumeFailures), ResumeFailureAction.skipTrack);
    });
  });
}
