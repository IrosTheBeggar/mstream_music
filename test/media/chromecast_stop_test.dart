import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/chromecast_playback_backend.dart';
import 'package:mstream_music/media/playback_backend.dart';

/// Exposes the protected playlist bookkeeping so the test can seed the
/// "track loaded on the receiver" state without a live Cast session. The
/// plugin's channel calls throw MissingPluginException here, which stop()
/// swallows — exactly like a broken session in production.
class _TestableCast extends ChromecastPlaybackBackend {
  _TestableCast() : super(deviceId: 'test-device');

  void seedLoaded(int i) {
    index = i;
    loadedIndex = i;
    playing = true;
  }

  int get exposedLoadedIndex => loadedIndex;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChromecastPlaybackBackend.stop', () {
    // Regression: stop() unloads the receiver's media session but used to keep
    // loadedIndex, so the next play() fast-pathed into a bare _client.play()
    // against a session-less receiver and reported "playing" over silence.
    test('resets loadedIndex so the next play() must reload', () async {
      final b = _TestableCast();
      b.seedLoaded(0);
      expect(b.exposedLoadedIndex, 0, reason: 'seeded as loaded');

      await b.stop();

      expect(b.exposedLoadedIndex, -1,
          reason: 'stop() unloaded the receiver session; loadedIndex must not '
              'claim a track is still loaded');
      expect(b.playing, isFalse);
      expect(b.processingState, BackendProcessingState.idle);
    });
  });
}
