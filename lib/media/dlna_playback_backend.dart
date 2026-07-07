import 'dart:async';
import 'dart:io' show File;

import 'package:audio_service/audio_service.dart' show MediaItem;
// Hide media_cast_dlna's own MediaItem — we use audio_service's MediaItem for
// queue items and only need the plugin's control/metadata types here.
import 'package:media_cast_dlna/media_cast_dlna.dart' hide MediaItem;
import 'package:meta/meta.dart';

import 'cast_art.dart';
import 'cast_log.dart';
import 'cast_origin.dart';
import 'emulated_playlist_backend.dart';
import 'local_media_server.dart';
import 'playback_backend.dart';

/// [PlaybackBackend] that plays through a DLNA renderer (TV / AV receiver /
/// speaker) via the native `media_cast_dlna` plugin.
///
/// A DLNA renderer plays ONE track at a time, so this emulates just_audio's
/// playlist through [EmulatedPlaylistBackend]: the base owns the source list +
/// current index and the add/remove/move/clear arithmetic; this subclass pushes
/// the current track with `setMediaUri`, polls position/duration/state ~1 Hz via
/// `getPlaybackInfo`, and advances to the next track when the renderer reports
/// it has STOPPED near the end. Position/duration/state are re-broadcast through
/// the base's streams (the same ones the AudioPlayerHandler already consumes) —
/// so the queue, Auto-DJ and now-playing UI keep working unchanged while
/// casting.
///
/// Shuffle/repeat are emulated by the base (just_audio handles them natively for
/// the local backend).
class DlnaPlaybackBackend extends EmulatedPlaylistBackend {
  DlnaPlaybackBackend({required String udn, MediaCastDlnaApi? api})
      : _udn = DeviceUdn(value: udn),
        _api = api ?? MediaCastDlnaApi();

  final MediaCastDlnaApi _api;
  final DeviceUdn _udn;

  bool _advancing = false; // guards against double-advance while a track loads
  bool _confirmedPlaying = false; // renderer reached PLAYING for the current track
  bool _reachedNearEnd = false; // position reached end-of-track while playing

  Timer? _pollTimer;
  bool _polling = false;
  bool _disposed = false;

  // Consecutive getPlaybackInfo failures; trips a mid-cast "renderer lost"
  // fallback once it crosses _kMaxPollFailures (so a single Wi-Fi blip doesn't).
  int _pollFailures = 0;
  static const int _kMaxPollFailures = 4;

  // ── Transport ──
  // DLNA renderers fetch the URL themselves. A plain HTTP server id is handed
  // over as-is; a local-only item (file-explorer track — id is a UUID) is served
  // from the phone's LocalMediaServer; an iroh server's id is the phone-loopback
  // tunnel URL the renderer can't reach, so it's relayed through the
  // LocalMediaServer proxy (re-bound to the live tunnel).
  Future<Uri> _resolveUri(MediaItem item) async {
    final localPath = item.extras?['localPath'] as String?;
    final isNetwork =
        item.id.startsWith('http://') || item.id.startsWith('https://');
    if (!isNetwork && localPath != null && File(localPath).existsSync()) {
      await LocalMediaServer().ensureStarted();
      return LocalMediaServer().registerFile(localPath);
    }
    final iroh = irohServerFor(item);
    if (iroh != null) {
      await LocalMediaServer().ensureStarted();
      // A downloaded iroh track is already on disk — serve it from there (faster,
      // and it skips the tunnel relay). Its id is a 127.0.0.1 loopback URL, so
      // isNetwork is true and the disk branch above is bypassed; handle it here.
      if (localPath != null && File(localPath).existsSync()) {
        return LocalMediaServer().registerFile(localPath);
      }
      return irohProxyUri(iroh, item.id);
    }
    return Uri.parse(item.id);
  }

  AudioMetadata _metaFor(MediaItem item) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV; for an
    // iroh server it's relayed through the LAN proxy (LocalMediaServer already
    // started by _resolveUri above) so the renderer can fetch it.
    final art = castArtUriFor(item);
    return AudioMetadata(
      title: item.title,
      artist: item.artist,
      album: item.album,
      originalTrackNumber: intExtra(item, 'track'),
      duration: item.duration != null
          ? TimeDuration(seconds: item.duration!.inSeconds)
          : null,
      albumArtUri: art != null ? Url(value: art) : null,
    );
  }

  @protected
  @override
  Future<bool> loadIndex(int target, {required bool play}) async {
    if (target < 0 || target >= items.length) return false;
    index = target;
    emitIndex(target);
    final item = items[target];
    _confirmedPlaying = false;
    _reachedNearEnd = false;
    setProcessingState(BackendProcessingState.loading);
    var ok = false;
    try {
      final uri = await _resolveUri(item);
      await _api.setMediaUri(_udn, Url(value: uri.toString()), _metaFor(item));
      loadedIndex = target;
      duration = item.duration;
      emitDur(duration);
      position = Duration.zero;
      emitPos(position);
      if (play) {
        await _api.play(_udn);
        playing = true;
      }
      setProcessingState(BackendProcessingState.ready);
      _startPolling();
      ok = true;
    } catch (e) {
      castLog('DLNA load failed', error: e);
    }
    change();
    return ok;
  }

  @override
  Future<void> play() async {
    if (index < 0) return;
    if (loadedIndex != index) {
      await loadIndex(index, play: true);
      return;
    }
    try {
      await _api.play(_udn);
    } catch (_) {}
    playing = true;
    setProcessingState(BackendProcessingState.ready);
    _startPolling();
    change();
  }

  @override
  Future<void> pause() async {
    try {
      await _api.pause(_udn);
    } catch (_) {}
    playing = false;
    change();
  }

  @override
  Future<void> stop() async {
    await _stopRenderer();
    playing = false;
    setProcessingState(BackendProcessingState.idle);
    change();
  }

  Future<void> _stopRenderer() async {
    _stopPolling();
    try {
      await _api.stop(_udn);
    } catch (_) {}
  }

  @protected
  @override
  Future<void> stopForEmptyList() async {
    await _stopRenderer();
    setProcessingState(BackendProcessingState.idle);
  }

  @override
  Future<void> seek(Duration position, {int? index, bool? play}) async {
    final target = index ?? this.index;
    if (target >= 0 && target != loadedIndex) {
      await loadIndex(target, play: play ?? playing);
    }
    try {
      await _api.seek(_udn, TimePosition(seconds: position.inSeconds));
    } catch (_) {}
    this.position = position;
    emitPos(position);
    change();
  }

  @override
  Future<void> seekToNext() async {
    final n = nextIndex();
    if (n != null) {
      await loadIndex(n,
          play: playing || processingState == BackendProcessingState.ready);
    }
  }

  @override
  Future<void> seekToPrevious() async {
    if (index > 0) {
      await loadIndex(index - 1, play: playing);
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _api.setVolume(
          _udn, VolumeLevel(percentage: (volume.clamp(0.0, 1.0) * 100).round()));
    } catch (_) {}
  }

  // ── Polling engine: drives position/duration/state + auto-advance ──
  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final info =
          await _api.getPlaybackInfo(_udn).timeout(const Duration(seconds: 2));
      _pollFailures = 0;
      position = Duration(seconds: info.position.seconds);
      emitPos(position);
      if (info.duration.seconds > 0) {
        duration = Duration(seconds: info.duration.seconds);
        emitDur(duration);
      }
      // Latch once we've genuinely reached the end while playing — robust to
      // renderers that reset position to 0 when they stop at track end.
      final dur = duration;
      if (dur != null &&
          dur > Duration.zero &&
          position >= dur - const Duration(seconds: 5)) {
        _reachedNearEnd = true;
      }
      switch (info.state) {
        case TransportState.playing:
          playing = true;
          _advancing = false;
          _confirmedPlaying = true;
          setProcessingState(BackendProcessingState.ready);
          break;
        case TransportState.paused:
          playing = false;
          break;
        case TransportState.transitioning:
          setProcessingState(BackendProcessingState.buffering);
          break;
        case TransportState.stopped:
          await _onRendererStopped();
          break;
        case TransportState.noMediaPresent:
          break;
      }
      change();
    } catch (_) {
      // A single failure is usually a transient renderer/network blip — keep
      // polling. But a renderer that's genuinely gone (TV off, Wi-Fi dropped)
      // fails every poll; after _kMaxPollFailures in a row, declare it lost so
      // the handler can fall back to local playback.
      if (!_disposed && ++_pollFailures >= _kMaxPollFailures) {
        _stopPolling();
        emitRendererLost(
            'Lost connection to the cast device — back on this phone');
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _onRendererStopped() async {
    // Only treat STOPPED as end-of-track if the track actually started
    // (ignores the transient STOPPED during the load->play transition that
    // otherwise skips a freshly-selected track) AND playback reached the end.
    // Without these guards a just-loaded track skips after a few seconds.
    if (_advancing || !_confirmedPlaying || !_reachedNearEnd) return;
    _advancing = true;
    final n = nextIndex(onComplete: true);
    if (n != null) {
      await loadIndex(n, play: true); // _advancing cleared when poll sees PLAYING
    } else {
      playing = false;
      _advancing = false;
      setProcessingState(BackendProcessingState.completed);
      _stopPolling();
    }
  }

  @protected
  @override
  Future<void> disposeRenderer() async {
    _disposed = true;
    _stopPolling();
    await _stopRenderer();
  }
}
