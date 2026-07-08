import 'dart:async';

import 'package:audio_service/audio_service.dart' show MediaItem;
// Hide media_cast_dlna's own MediaItem — we use audio_service's MediaItem for
// queue items and only need the plugin's control/metadata types here.
import 'package:media_cast_dlna/media_cast_dlna.dart' hide MediaItem;
import 'package:meta/meta.dart';

import '../util/connectivity_probe.dart';
import 'cast_art.dart';
import 'cast_log.dart';
import 'cast_origin.dart';
import 'emulated_playlist_backend.dart';
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

  bool _confirmedPlaying = false; // renderer reached PLAYING for the current track
  bool _reachedNearEnd = false; // position reached end-of-track while playing
  // Furthest position seen while PLAYING for the current track. Some renderers
  // reset position to 0 the moment they stop, so the STOPPED classification
  // below reads this instead of the (already-overwritten) live position.
  Duration _lastPlayingPosition = Duration.zero;
  // A renderer stuck fetching media it can never get (dead iroh tunnel, dead
  // server) answers every poll in TRANSITIONING forever — no poll failure, no
  // stop. Track how long a load has gone without reaching playback; past the
  // threshold the track is failed into the bounded walk.
  DateTime? _loadingSince;
  static const Duration _kStuckLoadingAfter = Duration(seconds: 30);

  Timer? _pollTimer;
  bool _polling = false;
  bool _disposed = false;

  // Consecutive getPlaybackInfo failures; trips a mid-cast "renderer lost"
  // fallback once it crosses _kMaxPollFailures (so a single Wi-Fi blip doesn't).
  int _pollFailures = 0;
  static const int _kMaxPollFailures = 4;

  AudioMetadata _metaFor(MediaItem item) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV; for an
    // iroh server it's relayed through the LAN proxy (LocalMediaServer already
    // started by resolveRendererUri) so the renderer can fetch it.
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
    _lastPlayingPosition = Duration.zero;
    _loadingSince = DateTime.now();
    setProcessingState(BackendProcessingState.loading);
    var ok = false;
    try {
      final uri = await resolveRendererUri(item);
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
      final ok = await loadIndex(index, play: true);
      if (!ok) await trackFailed('load failed', play: true);
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
      final intent = play ?? playing;
      final ok = await loadIndex(target, play: intent);
      // A failed user-driven load would otherwise strand the backend in
      // 'loading' with no watchdog running (polling only starts on success).
      if (!ok) await trackFailed('load failed', play: intent);
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
      final intent =
          playing || processingState == BackendProcessingState.ready;
      final ok = await loadIndex(n, play: intent);
      if (!ok) await trackFailed('load failed', play: intent);
    }
  }

  @override
  Future<void> seekToPrevious() async {
    if (index > 0) {
      final intent = playing;
      final ok = await loadIndex(index - 1, play: intent);
      if (!ok) await trackFailed('load failed', play: intent);
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
          trackPlaying();
          _confirmedPlaying = true;
          _loadingSince = null;
          if (position > _lastPlayingPosition) _lastPlayingPosition = position;
          setProcessingState(BackendProcessingState.ready);
          break;
        case TransportState.paused:
          playing = false;
          _loadingSince = null;
          break;
        case TransportState.transitioning:
          _loadingSince ??= DateTime.now();
          setProcessingState(BackendProcessingState.buffering);
          break;
        case TransportState.stopped:
          await _onRendererStopped();
          break;
        case TransportState.noMediaPresent:
          break;
      }
      final loading = _loadingSince;
      if (loading != null &&
          DateTime.now().difference(loading) > _kStuckLoadingAfter) {
        _loadingSince = null;
        await trackFailed(
            'renderer stuck loading for ${_kStuckLoadingAfter.inSeconds}s',
            play: playing);
      }
      change();
    } catch (_) {
      // A single failure is usually a transient renderer/network blip — keep
      // polling. But a renderer that's genuinely gone (TV off, Wi-Fi dropped)
      // fails every poll; after _kMaxPollFailures in a row, declare it lost so
      // the handler can fall back to local playback.
      if (!_disposed && ++_pollFailures >= _kMaxPollFailures) {
        // The renderer pulls its stream from the server directly, so when the
        // PHONE's own LAN is what dropped, the cast is usually still playing
        // fine — hold instead of tearing a working cast down and falling back
        // to a phone that is itself offline. Polls keep retrying; the first
        // success resets the counter, and a threshold crossing once the LAN
        // is back means the renderer is genuinely gone.
        if (!await hasConnectivity(lanOnly: true)) {
          _pollFailures = _kMaxPollFailures; // hold at the threshold
          return;
        }
        _stopPolling();
        emitRendererLost(
            'Lost connection to the cast device — back on this phone');
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _onRendererStopped() async {
    // Ignore the transient STOPPED during the load→play transition — without
    // the _confirmedPlaying guard a freshly-selected track skips after a few
    // seconds. (advancing additionally collapses the repeated STOPPED polls
    // while the next track loads.)
    if (advancing || !_confirmedPlaying) return;
    final dur = duration;
    // With no usable duration (missing metadata, or a renderer that reports
    // 0), _reachedNearEnd can never latch — accept a stop after real playing
    // progress as the track's natural end, or such queues halt after every
    // single track.
    final endedWithoutDuration = (dur == null || dur == Duration.zero) &&
        _lastPlayingPosition >= const Duration(seconds: 5);
    if (_reachedNearEnd || endedWithoutDuration) {
      await advanceOnComplete();
    } else {
      // Stopped well before the end: the renderer aborted (fetch/decode
      // error). Walk on (bounded) instead of ignoring the stop forever with
      // the published state stuck on 'playing'. Known tradeoff: a stop issued
      // from the renderer's OWN remote / another control point is
      // indistinguishable from an abort and also walks — recovering the
      // dead-server case is worth that rare misfire.
      final wasPlaying = playing;
      playing = false;
      await trackFailed(
          'renderer stopped mid-track at ${_lastPlayingPosition.inSeconds}s',
          play: wasPlaying);
    }
  }

  // The advance walk settled (end of a non-repeating list, or it gave up and
  // declared the renderer lost) — nothing is playing, so stop the 1 Hz poll.
  @override
  void onPlaybackSettled() => _stopPolling();

  @protected
  @override
  Future<void> disposeRenderer() async {
    _disposed = true;
    _stopPolling();
    await _stopRenderer();
  }
}
