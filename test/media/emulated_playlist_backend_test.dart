import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/emulated_playlist_backend.dart';
import 'package:mstream_music/media/playback_backend.dart';

/// Scriptable stand-in for a renderer backend: loads succeed/fail per
/// [loadResult], and the protected advance API is exposed for the tests.
class _FakeBackend extends EmulatedPlaylistBackend {
  _FakeBackend() {
    failureWalkDelay = Duration.zero; // tests must not sleep between strikes
  }

  final List<String> loads = [];
  bool Function(int index)? loadResult;
  int settledCalls = 0;

  @override
  Future<bool> loadIndex(int target, {required bool play}) async {
    // Mirror the real backends: the logical index moves to the target before
    // the renderer push is attempted; loadedIndex only on success.
    index = target;
    emitIndex(target);
    loads.add('$target:${play ? 'play' : 'pause'}');
    final ok = loadResult?.call(target) ?? true;
    if (ok) loadedIndex = target;
    return ok;
  }

  @override
  Future<void> stopForEmptyList() async {}

  @override
  Future<void> disposeRenderer() async {}

  @override
  void onPlaybackSettled() {
    settledCalls++;
  }

  // Public wrappers for the protected advance API.
  Future<void> endOfTrack() => advanceOnComplete();
  Future<void> failTrack(String reason, {bool play = true}) =>
      trackFailed(reason, play: play);
  void confirmPlaying() => trackPlaying();
  bool get isAdvancing => advancing;

  // Inert transport (not under test).
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position, {int? index, bool? play}) async {}
  @override
  Future<void> seekToNext() async {}
  @override
  Future<void> seekToPrevious() async {}
  @override
  Future<void> setVolume(double volume) async {}
}

MediaItem _item(int i) => MediaItem(id: 'id-$i', title: 'Track $i');

Future<_FakeBackend> _seeded(int count) async {
  final b = _FakeBackend();
  await b.setSources(List.generate(count, _item));
  return b;
}

void main() {
  group('advanceOnComplete', () {
    test('advances to the next index and loads it playing', () async {
      final b = await _seeded(3);
      await b.endOfTrack();
      expect(b.loads, ['1:play']);
      expect(b.currentIndex, 1);
    });

    test('settles completed at the end of a non-repeating list', () async {
      final b = await _seeded(3);
      await b.loadIndex(2, play: true);
      b.confirmPlaying();
      b.loads.clear();
      await b.endOfTrack();
      expect(b.loads, isEmpty);
      expect(b.processingState, BackendProcessingState.completed);
      expect(b.playing, isFalse);
      expect(b.settledCalls, 1);
      expect(b.isAdvancing, isFalse);
    });

    test('wraps to 0 under repeat-all', () async {
      final b = await _seeded(3);
      await b.setRepeat(BackendRepeat.all);
      await b.loadIndex(2, play: true);
      b.confirmPlaying();
      b.loads.clear();
      await b.endOfTrack();
      expect(b.loads, ['0:play']);
    });

    test('repeat-one reloads the same track', () async {
      final b = await _seeded(3);
      await b.setRepeat(BackendRepeat.one);
      await b.loadIndex(1, play: true);
      b.confirmPlaying();
      b.loads.clear();
      await b.endOfTrack();
      expect(b.loads, ['1:play']);
    });

    test('duplicate end events while the latch is held advance once',
        () async {
      final b = await _seeded(5);
      await b.endOfTrack(); // latches advancing (no PLAYING confirm yet)
      await b.endOfTrack();
      await b.endOfTrack();
      expect(b.loads, ['1:play']);
    });

    test(
        'a renderer failure of the walk-loaded track releases the latch and '
        'keeps walking (loadIndex resolves before the renderer fetches)',
        () async {
      final b = await _seeded(5);
      await b.endOfTrack(); // loads 1 successfully, latch held pending PLAYING
      expect(b.loads, ['1:play']);
      // The receiver then fails to FETCH track 1 (proxy 502 / dead tunnel):
      // this arrives as a failure event while the latch is still held.
      await b.failTrack('receiver reported a media error');
      expect(b.loads, ['1:play', '2:play']); // walked on — no wedge
    });
  });

  group('trackFailed (bounded failure walk)', () {
    test('a failed advance load walks on to the following track', () async {
      final b = await _seeded(5);
      b.loadResult = (i) => i != 1; // only index 1 is broken
      await b.endOfTrack();
      expect(b.loads, ['1:play', '2:play']);
      expect(b.currentIndex, 2);
    });

    test(
        'gives up after kMaxTrackFailures consecutive failures and '
        'declares the renderer lost once', () async {
      final b = await _seeded(10);
      b.loadResult = (_) => false; // everything is broken
      final lost = <String>[];
      b.rendererLostStream.listen(lost.add);
      await b.endOfTrack();
      await Future<void>.delayed(Duration.zero); // let the stream deliver
      expect(b.loads.length, EmulatedPlaylistBackend.kMaxTrackFailures);
      expect(lost, hasLength(1));
      expect(b.isAdvancing, isFalse); // no wedge: latch released
    });

    test('confirmed playback resets the failure budget', () async {
      final b = await _seeded(10);
      b.loadResult = (i) => i == 3; // two failures, then 3 loads fine
      final lost = <String>[];
      b.rendererLostStream.listen(lost.add);
      await b.endOfTrack(); // 1 fails, 2 fails, 3 loads
      b.confirmPlaying();
      b.loadResult = (_) => false;
      await b.endOfTrack(); // needs 3 FRESH failures to trip
      await Future<void>.delayed(Duration.zero);
      expect(lost, hasLength(1)); // not 2 — the first walk never tripped
      expect(b.loads, ['1:play', '2:play', '3:play', '4:play', '5:play', '6:play']);
    });

    test('preserves a paused play intent through the walk', () async {
      final b = await _seeded(5);
      b.loadResult = (i) => i == 2;
      await b.failTrack('renderer stopped', play: false);
      expect(b.loads, ['1:pause', '2:pause']);
    });

    test('is a no-op on an empty list', () async {
      final b = _FakeBackend();
      await b.setSources(const []);
      await b.failTrack('anything');
      expect(b.loads, isEmpty);
    });

    test('a mid-walk failure does not wedge the following natural advance',
        () async {
      final b = await _seeded(5);
      b.loadResult = (i) => i != 1; // one broken track, then healthy
      await b.endOfTrack(); // 1 fails, 2 loads (latch held until PLAYING)
      b.confirmPlaying();
      b.loads.clear();
      await b.endOfTrack();
      expect(b.loads, ['3:play']); // advances normally — no wedge
    });

    test(
        'after renderer-lost the walk quiesces — straggler renderer events '
        'cannot restart it while the handler swaps backends', () async {
      final b = await _seeded(5);
      b.loadResult = (_) => false;
      await b.endOfTrack(); // trips renderer-lost
      expect(b.settledCalls, 1); // quiesce hook fired (DLNA stops polling)
      b.loadResult = null;
      b.loads.clear();
      await b.endOfTrack();
      await b.failTrack('straggler poll');
      expect(b.loads, isEmpty);
    });
  });
}
