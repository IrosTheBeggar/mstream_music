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

  // Records reloads instead of talking to the plugin, so the play-after-stop
  // test can assert the ROUTE play() took: the fixed path calls loadIndex
  // (reloading the receiver), the broken fast path never did.
  final List<({int index, bool play})> loadCalls = [];

  @override
  Future<bool> loadIndex(int target,
      {required bool play, Duration startAt = Duration.zero}) async {
    loadCalls.add((index: target, play: play));
    loadedIndex = target;
    if (play) playing = true;
    return true;
  }
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

    // The other half of the contract: with loadedIndex reset, the next play()
    // must ROUTE THROUGH loadIndex (reloading the track on the receiver). The
    // broken fast path issued a bare _client.play() against the unloaded
    // session — a swallowed no-op reported as "playing" — and never reloaded.
    test('play() after stop() reloads via loadIndex', () async {
      final b = _TestableCast();
      b.seedLoaded(0);
      await b.stop();

      await b.play();

      expect(b.loadCalls, [(index: 0, play: true)],
          reason: 'a session-less receiver needs a fresh LOAD, not a bare '
              'play()');
      expect(b.playing, isTrue);
    });
  });
}
