import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

/// The state a cold-boot play publishes while it waits for the queue restore,
/// so audio_service takes the service into the foreground before One UI's
/// freezer (ten seconds after a headless start) suspends the process.
void main() {
  group('AudioPlayerHandler.restoreHoldState', () {
    final idle = PlaybackState(
        processingState: AudioProcessingState.idle,
        controls: const [MediaControl.play],
        queueIndex: 3,
        shuffleMode: AudioServiceShuffleMode.all);

    test('on Android a paused state is held as playing, all else kept', () {
      final held =
          AudioPlayerHandler.restoreHoldState(idle, isAndroid: true)!;
      expect(held.playing, isTrue);
      expect(held.processingState, AudioProcessingState.idle);
      expect(held.controls, idle.controls);
      expect(held.queueIndex, 3);
      expect(held.shuffleMode, AudioServiceShuffleMode.all);
    });

    test('the processing state is never touched: idle stays idle', () {
      // audio_service stops the service on a transition INTO idle, so a hold
      // that raised the state and then fell back would tear the service down.
      final held =
          AudioPlayerHandler.restoreHoldState(idle, isAndroid: true)!;
      expect(held.processingState, idle.processingState);
    });

    test('nothing to hold off Android', () {
      expect(AudioPlayerHandler.restoreHoldState(idle, isAndroid: false),
          isNull);
    });

    test('nothing to hold when already playing', () {
      final playing = idle.copyWith(playing: true);
      expect(AudioPlayerHandler.restoreHoldState(playing, isAndroid: true),
          isNull);
    });
  });
}
