import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.mediaToggleAction', () {
    MediaToggleAction act({bool playing = false, Duration? sinceOutputLost}) =>
        AudioPlayerHandler.mediaToggleAction(
            playing: playing, sinceOutputLost: sinceOutputLost);

    test('playing → pause, whatever happened to the output', () {
      expect(act(playing: true), MediaToggleAction.pause);
      expect(act(playing: true, sinceOutputLost: const Duration(seconds: 5)),
          MediaToggleAction.pause);
    });

    test('paused with no output loss on record → play', () {
      expect(act(), MediaToggleAction.play);
    });

    // The regression this exists for: the car's explicit PAUSE arrives after
    // the audio link has already dropped and paused us, and audio_service
    // hands it over as a toggle — which used to un-pause onto the speaker.
    test('paused inside the window after an output loss → ignore', () {
      expect(act(sinceOutputLost: const Duration(seconds: 11)),
          MediaToggleAction.ignore);
      expect(act(sinceOutputLost: const Duration(seconds: 29)),
          MediaToggleAction.ignore);
    });

    test('the window is 30s', () {
      expect(AudioPlayerHandler.kOutputLostToggleWindow,
          const Duration(seconds: 30));
      expect(act(sinceOutputLost: const Duration(seconds: 30)),
          MediaToggleAction.play);
      expect(act(sinceOutputLost: const Duration(minutes: 5)),
          MediaToggleAction.play);
    });
  });
}
