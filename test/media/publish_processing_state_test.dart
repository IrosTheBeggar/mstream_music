import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.publishProcessingState', () {
    // audio_service stops the Android service on every published
    // non-idle→idle transition, so which idles pass through is load-bearing:
    // deliberate teardown must publish idle (service stops, notification
    // clears); an error-induced idle with tracks still queued must NOT
    // (backgrounded, that teardown destroys the engine mid-recovery).

    test('error-induced idle with a queued track publishes error', () {
      expect(
        AudioPlayerHandler.publishProcessingState(BackendProcessingState.idle,
            intentionalStop: false, queueEmpty: false),
        AudioProcessingState.error,
      );
    });

    test('intentional stop passes idle through', () {
      expect(
        AudioPlayerHandler.publishProcessingState(BackendProcessingState.idle,
            intentionalStop: true, queueEmpty: false),
        AudioProcessingState.idle,
      );
    });

    test('idle with an empty queue passes through (cleared / cold start)', () {
      expect(
        AudioPlayerHandler.publishProcessingState(BackendProcessingState.idle,
            intentionalStop: false, queueEmpty: true),
        AudioProcessingState.idle,
      );
    });

    test('non-idle states map straight through regardless of flags', () {
      const expected = {
        BackendProcessingState.loading: AudioProcessingState.loading,
        BackendProcessingState.buffering: AudioProcessingState.buffering,
        BackendProcessingState.ready: AudioProcessingState.ready,
        BackendProcessingState.completed: AudioProcessingState.completed,
      };
      for (final entry in expected.entries) {
        for (final intentional in [true, false]) {
          for (final empty in [true, false]) {
            expect(
              AudioPlayerHandler.publishProcessingState(entry.key,
                  intentionalStop: intentional, queueEmpty: empty),
              entry.value,
              reason: '${entry.key} intentional=$intentional empty=$empty',
            );
          }
        }
      }
    });
  });
}
