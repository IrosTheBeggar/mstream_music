import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.shouldReseedOnPlay', () {
    // A bare backend.play() is a silent no-op once just_audio has parked idle
    // (a playback error tears the platform player down), so play() must
    // re-seed the sources instead — but ONLY then: re-seeding a live player
    // on every tap would hiccup normal resume.

    test('idle local player with queued tracks → re-seed', () {
      expect(
        AudioPlayerHandler.shouldReseedOnPlay(
            onLocalBackend: true,
            processingState: BackendProcessingState.idle,
            queueEmpty: false,
            recovering: false),
        isTrue,
      );
    });

    test('cast backend → never (renderer owns its own load state)', () {
      expect(
        AudioPlayerHandler.shouldReseedOnPlay(
            onLocalBackend: false,
            processingState: BackendProcessingState.idle,
            queueEmpty: false,
            recovering: false),
        isFalse,
      );
    });

    test('empty queue → nothing to re-seed', () {
      expect(
        AudioPlayerHandler.shouldReseedOnPlay(
            onLocalBackend: true,
            processingState: BackendProcessingState.idle,
            queueEmpty: true,
            recovering: false),
        isFalse,
      );
    });

    test('recovery in flight → defer to it (it reads the play intent)', () {
      expect(
        AudioPlayerHandler.shouldReseedOnPlay(
            onLocalBackend: true,
            processingState: BackendProcessingState.idle,
            queueEmpty: false,
            recovering: true),
        isFalse,
      );
    });

    test('any non-idle state → bare play', () {
      for (final state in BackendProcessingState.values) {
        if (state == BackendProcessingState.idle) continue;
        expect(
          AudioPlayerHandler.shouldReseedOnPlay(
              onLocalBackend: true,
              processingState: state,
              queueEmpty: false,
              recovering: false),
          isFalse,
          reason: '$state must not trigger a re-seed',
        );
      }
    });
  });
}
