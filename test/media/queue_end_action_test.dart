import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.queueEndAction', () {
    QueueEndAction act({
      bool onLocalBackend = true,
      bool isIrohDJ = true,
      bool djPickPending = true,
      bool playIntent = true,
      bool tunnelServes = false,
      bool pickInFlight = false,
    }) =>
        AudioPlayerHandler.queueEndAction(
            onLocalBackend: onLocalBackend,
            isIrohDJ: isIrohDJ,
            djPickPending: djPickPending,
            playIntent: playIntent,
            tunnelServes: tunnelServes,
            pickInFlight: pickInFlight);

    // The regression this exists for: an outage-drained queue used to stop()
    // like a user stop, which set the intentional-stop flag and made every
    // later tunnel-back edge a no-op.
    test('pick owed to the outage + playback wanted + tunnel down → park', () {
      expect(act(), QueueEndAction.park);
    });

    // A transient POST failure with the tunnel fine has no edge to wait for:
    // a park would be a silent 30-minute wait. Retry now, stop if it fails.
    test('pick owed but the tunnel is serving → retry the pick now', () {
      expect(act(tunnelServes: true), QueueEndAction.retryPick);
    });

    test('tunnel serving but a pick is already in flight → park (it lands)',
        () {
      expect(act(tunnelServes: true, pickInFlight: true), QueueEndAction.park);
    });

    // The top-up POST is out but has not failed yet (nothing pending): the
    // pick is still owed — it lands and resumes, or fails into pending.
    test('pick in flight with nothing pending yet → park', () {
      expect(act(djPickPending: false, pickInFlight: true), QueueEndAction.park);
      expect(
          act(djPickPending: false, pickInFlight: true, tunnelServes: true),
          QueueEndAction.park);
    });

    test('no pick pending (a normal end) → stop', () {
      expect(act(djPickPending: false), QueueEndAction.stop);
      expect(act(djPickPending: false, tunnelServes: true),
          QueueEndAction.stop);
    });

    test('the user had paused → stop (their intent wins)', () {
      expect(act(playIntent: false), QueueEndAction.stop);
    });

    // A cast session or an HTTP DJ server has no tunnel edge to wait for;
    // parking would be a silent 30-minute wait.
    test('casting, or an HTTP Auto DJ server → stop', () {
      expect(act(onLocalBackend: false), QueueEndAction.stop);
      expect(act(isIrohDJ: false), QueueEndAction.stop);
    });
  });

  group('AudioPlayerHandler.shouldDeferDJPick', () {
    test('only an iroh server whose tunnel is not serving defers', () {
      expect(
          AudioPlayerHandler.shouldDeferDJPick(
              isIroh: true, tunnelServes: false),
          isTrue);
      expect(
          AudioPlayerHandler.shouldDeferDJPick(
              isIroh: true, tunnelServes: true),
          isFalse);
      expect(
          AudioPlayerHandler.shouldDeferDJPick(
              isIroh: false, tunnelServes: false),
          isFalse);
    });
  });

  group('AudioPlayerHandler.shouldRetryDeferredPick', () {
    bool retry({
      bool pending = true,
      bool tunnelServes = true,
      bool onLocalBackend = true,
      bool intentionalStop = false,
      int failures = 0,
    }) =>
        AudioPlayerHandler.shouldRetryDeferredPick(
            pending: pending,
            tunnelServes: tunnelServes,
            onLocalBackend: onLocalBackend,
            intentionalStop: intentionalStop,
            failures: failures);

    test('all gates open → retry', () {
      expect(retry(), isTrue);
    });

    test('each gate closes it', () {
      expect(retry(pending: false), isFalse);
      expect(retry(tunnelServes: false), isFalse);
      expect(retry(onLocalBackend: false), isFalse);
      expect(retry(intentionalStop: true), isFalse);
    });

    test('bounded by kMaxDeferredPickFailures', () {
      expect(retry(failures: AudioPlayerHandler.kMaxDeferredPickFailures - 1),
          isTrue);
      expect(retry(failures: AudioPlayerHandler.kMaxDeferredPickFailures),
          isFalse);
    });
  });
}
