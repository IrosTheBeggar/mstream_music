import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cast_dlna/media_cast_dlna.dart' hide MediaItem;
import 'package:mstream_music/media/dlna_playback_backend.dart';

/// Fake pigeon API: every method the backend touches is overridden, so no
/// platform channel is ever hit. Poll responses are scripted through [polls]
/// (the last entry repeats once the script runs out).
class _FakeDlnaApi extends MediaCastDlnaApi {
  final List<String> calls = [];
  final List<PlaybackInfo> polls = [];
  int pollCount = 0;
  bool Function(String uri)? setMediaUriOk;

  @override
  Future<void> setMediaUri(
      DeviceUdn deviceUdn, Url uri, MediaMetadata metadata) async {
    calls.add('set:${uri.value}');
    if (!(setMediaUriOk?.call(uri.value) ?? true)) {
      throw PlatformException(code: 'timeout', message: 'SOAP timeout');
    }
  }

  @override
  Future<void> play(DeviceUdn deviceUdn) async => calls.add('play');

  @override
  Future<void> pause(DeviceUdn deviceUdn) async => calls.add('pause');

  @override
  Future<void> stop(DeviceUdn deviceUdn) async => calls.add('stop');

  @override
  Future<void> seek(DeviceUdn deviceUdn, TimePosition position) async {}

  @override
  Future<void> setVolume(DeviceUdn deviceUdn, VolumeLevel volume) async {}

  @override
  Future<PlaybackInfo> getPlaybackInfo(DeviceUdn deviceUdn) async {
    final i = pollCount < polls.length ? pollCount : polls.length - 1;
    pollCount++;
    return polls[i];
  }
}

PlaybackInfo _info(TransportState state, int posSec, int durSec) =>
    PlaybackInfo(
        state: state,
        position: TimePosition(seconds: posSec),
        duration: TimeDuration(seconds: durSec));

MediaItem _track(int i, {Duration? duration}) => MediaItem(
    id: 'http://server/media/$i.mp3', title: 'Track $i', duration: duration);

void main() {
  test('natural end (near-end latched) advances to the next track', () {
    fakeAsync((fa) {
      final api = _FakeDlnaApi();
      final b = DlnaPlaybackBackend(udn: 'udn', api: api);
      b.setSources(List.generate(3, (i) => _track(i)));
      fa.flushMicrotasks();
      b.play();
      fa.flushMicrotasks();
      expect(api.calls, ['set:http://server/media/0.mp3', 'play']);

      api.polls.addAll([
        _info(TransportState.playing, 100, 180),
        _info(TransportState.playing, 176, 180), // near-end latch
        _info(TransportState.stopped, 0, 180), // renderer stops at track end
      ]);
      fa.elapse(const Duration(seconds: 3));
      fa.flushMicrotasks();
      expect(api.calls, contains('set:http://server/media/1.mp3'));
      expect(b.currentIndex, 1);
    });
  });

  test('mid-track STOPPED is treated as a failure and walks on', () {
    fakeAsync((fa) {
      final api = _FakeDlnaApi();
      final b = DlnaPlaybackBackend(udn: 'udn', api: api);
      b.setSources(List.generate(3, (i) => _track(i)));
      fa.flushMicrotasks();
      b.play();
      fa.flushMicrotasks();

      api.polls.addAll([
        _info(TransportState.playing, 60, 180), // confirmed, far from the end
        _info(TransportState.stopped, 0, 180), // renderer aborted mid-track
      ]);
      fa.elapse(const Duration(seconds: 2));
      fa.flushMicrotasks();
      // Previously this wedged forever with state stuck on 'playing'.
      expect(api.calls, contains('set:http://server/media/1.mp3'));
      expect(b.currentIndex, 1);
    });
  });

  test('unknown duration: a stop after real progress is a natural end', () {
    fakeAsync((fa) {
      final api = _FakeDlnaApi();
      final b = DlnaPlaybackBackend(udn: 'udn', api: api);
      b.setSources(List.generate(2, (i) => _track(i))); // no item duration
      fa.flushMicrotasks();
      b.play();
      fa.flushMicrotasks();

      api.polls.addAll([
        _info(TransportState.playing, 30, 0), // renderer reports no duration
        _info(TransportState.stopped, 0, 0),
      ]);
      fa.elapse(const Duration(seconds: 2));
      fa.flushMicrotasks();
      // Previously the near-end latch could never set → stopped after every track.
      expect(api.calls, contains('set:http://server/media/1.mp3'));
    });
  });

  test('transient STOPPED before playback is confirmed is ignored', () {
    fakeAsync((fa) {
      final api = _FakeDlnaApi();
      final b = DlnaPlaybackBackend(udn: 'udn', api: api);
      b.setSources(List.generate(2, (i) => _track(i)));
      fa.flushMicrotasks();
      b.play();
      fa.flushMicrotasks();

      api.polls.add(_info(TransportState.stopped, 0, 180)); // load transition
      fa.elapse(const Duration(seconds: 3));
      fa.flushMicrotasks();
      expect(api.calls.where((c) => c.startsWith('set:')), hasLength(1));
      expect(b.currentIndex, 0);
    });
  });

  test(
      'persistent load failures give up, declare the renderer lost and stop '
      'polling', () {
    fakeAsync((fa) {
      final api = _FakeDlnaApi();
      final b = DlnaPlaybackBackend(udn: 'udn', api: api);
      final lost = <String>[];
      b.rendererLostStream.listen(lost.add);
      b.setSources(List.generate(6, (i) => _track(i)));
      fa.flushMicrotasks();
      b.play();
      fa.flushMicrotasks();

      // Track 0 plays, then every subsequent load times out at the renderer.
      api.setMediaUriOk = (uri) => uri.contains('/0.mp3');
      api.polls.addAll([
        _info(TransportState.playing, 100, 180),
        _info(TransportState.playing, 176, 180),
        _info(TransportState.stopped, 0, 180), // natural end → advance fails
      ]);
      fa.elapse(const Duration(seconds: 3));
      fa.flushMicrotasks();

      expect(lost, hasLength(1));
      // Walk attempted exactly kMaxTrackFailures loads before giving up.
      expect(api.calls.where((c) => c.startsWith('set:')).length, 1 + 3);
      final pollsAtLoss = api.pollCount;
      fa.elapse(const Duration(seconds: 5));
      expect(api.pollCount, pollsAtLoss); // polling quiesced
    });
  });
}
