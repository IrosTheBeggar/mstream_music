import 'dart:async';

import 'castv2/chromecast_sender.dart';
import 'cast_log.dart';
import 'desktop_chromecast_discoverer.dart';
import 'emulated_playlist_backend.dart';
import 'playback_backend.dart';

/// Desktop Chromecast playback backend: drives the pure-Dart [ChromecastSender]
/// (CASTV2) behind the shared single-item-push model in [EmulatedPlaylistBackend].
///
/// First cut: casts server stream URLs (the common case — audio streamed from the
/// mStream server, reachable by the Chromecast on the LAN). NOT yet handled:
/// downloaded/local files (would need the pure-Dart LocalMediaServer to serve
/// them), and loopback/iroh URLs / self-signed HTTPS (the device can't reach
/// 127.0.0.1 or won't trust a self-signed cert — a LocalMediaServer proxy is the
/// future fix). Needs testing against a real device.
class DesktopChromecastPlaybackBackend extends EmulatedPlaylistBackend {
  DesktopChromecastPlaybackBackend({required String deviceId})
      : _endpoint = DesktopChromecastDiscoverer.endpoints[deviceId];

  final ChromecastEndpoint? _endpoint;
  ChromecastSender? _sender;
  bool _connecting = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<CastPlayerState>? _stateSub;
  StreamSubscription<String>? _lostSub;

  Future<ChromecastSender?> _ensureConnected() async {
    if (_sender != null && _sender!.isReady) return _sender;
    if (_connecting) return _sender;
    final ep = _endpoint;
    if (ep == null) {
      emitRendererLost('Chromecast device not found on the network');
      return null;
    }
    _connecting = true;
    try {
      final s = ChromecastSender(ep.host, ep.port);
      await s.connect();
      _sender = s;
      _posSub = s.positionStream.listen((p) {
        position = p;
        emitPos(p);
        change();
      });
      _durSub = s.durationStream.listen((d) {
        duration = d;
        emitDur(d);
        change();
      });
      _stateSub = s.stateStream.listen(_onState);
      _lostSub = s.lostStream
          .listen((msg) => emitRendererLost('Cast connection lost'));
      return s;
    } catch (e) {
      castLog('Desktop Chromecast connect failed', error: e);
      emitRendererLost("Couldn't connect to the Chromecast");
      return null;
    } finally {
      _connecting = false;
    }
  }

  void _onState(CastPlayerState s) {
    switch (s) {
      case CastPlayerState.playing:
        playing = true;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastPlayerState.paused:
        playing = false;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastPlayerState.buffering:
        setProcessingState(BackendProcessingState.buffering);
        break;
      case CastPlayerState.finished:
        // Track ended on the device — advance like the local player does.
        final next = nextIndex(onComplete: true);
        if (next == null) {
          setProcessingState(BackendProcessingState.completed);
        } else {
          index = next;
          emitIndex(next);
          loadIndex(next, play: true);
        }
        break;
      case CastPlayerState.idle:
      case CastPlayerState.unknown:
        break;
    }
    change();
  }

  // ── EmulatedPlaylistBackend hooks ──
  @override
  Future<bool> loadIndex(int i, {required bool play}) async {
    if (i < 0 || i >= items.length) return false;
    final sender = await _ensureConnected();
    if (sender == null) return false;
    final item = items[i];
    final url = item.id;
    if (!url.startsWith('http')) {
      // Local/downloaded file — not yet served to the device on desktop.
      castLog('Desktop Chromecast: skipping non-HTTP source ${item.title}');
      emitRendererLost('Local files can’t be cast from desktop yet');
      return false;
    }
    loadedIndex = i;
    setProcessingState(BackendProcessingState.loading);
    playing = play;
    try {
      await sender.load(
        url: url,
        contentType: _audioMime(url),
        title: item.title,
        artist: item.artist,
        album: item.album,
        artUrl: item.extras?['artUrl'] as String? ?? item.artUri?.toString(),
        autoplay: play,
      );
    } catch (e) {
      // Contract: loadIndex never throws — a false feeds the base class's
      // bounded auto-advance failure walk.
      castLog('Desktop Chromecast load failed', error: e);
      change();
      return false;
    }
    change();
    return true;
  }

  @override
  Future<void> stopForEmptyList() async {
    await _sender?.stopMedia();
    playing = false;
    setProcessingState(BackendProcessingState.idle);
  }

  @override
  Future<void> disposeRenderer() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    await _lostSub?.cancel();
    await _sender?.dispose();
    _sender = null;
  }

  // ── Transport ──
  @override
  Future<void> play() async {
    playing = true;
    await _sender?.play();
    change();
  }

  @override
  Future<void> pause() async {
    playing = false;
    await _sender?.pause();
    change();
  }

  @override
  Future<void> stop() async {
    playing = false;
    await _sender?.stopMedia();
    setProcessingState(BackendProcessingState.idle);
    change();
  }

  @override
  Future<void> seek(Duration position, {int? index, bool? play}) async {
    if (index != null && index != loadedIndex) {
      this.index = index;
      emitIndex(index);
      await loadIndex(index, play: play ?? playing);
      if (position > Duration.zero) await _sender?.seek(position);
      return;
    }
    await _sender?.seek(position);
    if (play != null) {
      if (play) {
        await this.play();
      } else {
        await pause();
      }
    }
  }

  @override
  Future<void> seekToNext() async {
    final n = nextIndex();
    if (n == null) return;
    index = n;
    emitIndex(n);
    await loadIndex(n, play: playing);
  }

  @override
  Future<void> seekToPrevious() async {
    if (index <= 0) {
      await _sender?.seek(Duration.zero);
      return;
    }
    index = index - 1;
    emitIndex(index);
    await loadIndex(index, play: playing);
  }

  @override
  Future<void> setVolume(double volume) async => _sender?.setVolume(volume);

  static String _audioMime(String url) {
    final u = url.toLowerCase();
    if (u.contains('.flac')) return 'audio/flac';
    if (u.contains('.wav')) return 'audio/wav';
    if (u.contains('.ogg') || u.contains('.opus')) return 'audio/ogg';
    if (u.contains('.m4a') || u.contains('.aac') || u.contains('.mp4')) {
      return 'audio/mp4';
    }
    return 'audio/mpeg'; // mp3 + default
  }
}
