import 'dart:async';
import 'dart:math' show Random;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart' show AndroidEqualizer;
// Hide media_cast_dlna's own MediaItem — we use audio_service's MediaItem for
// queue items and only need the plugin's control/metadata types here.
import 'package:media_cast_dlna/media_cast_dlna.dart' hide MediaItem;
import 'package:rxdart/rxdart.dart';

import 'cast_art.dart';
import 'playback_backend.dart';

/// [PlaybackBackend] that plays through a DLNA renderer (TV / AV receiver /
/// speaker) via the native `media_cast_dlna` plugin.
///
/// A DLNA renderer plays ONE track at a time, so this emulates just_audio's
/// playlist: it owns the source list + current index, pushes the current track
/// with `setMediaUri`, and advances to the next when the renderer reports it
/// has STOPPED near the end. Position/duration/state are polled ~1 Hz via
/// `getPlaybackInfo` and re-broadcast through the same streams the
/// AudioPlayerHandler already consumes — so the queue, Auto-DJ and now-playing
/// UI keep working unchanged while casting.
///
/// Shuffle/repeat are emulated here (just_audio handles them natively for the
/// local backend); the implementation is intentionally simple for a first cut.
class DlnaPlaybackBackend implements PlaybackBackend {
  DlnaPlaybackBackend({required String udn, MediaCastDlnaApi? api})
      : _udn = DeviceUdn(value: udn),
        _api = api ?? MediaCastDlnaApi();

  final MediaCastDlnaApi _api;
  final DeviceUdn _udn;
  final Random _rng = Random();

  List<MediaItem> _items = <MediaItem>[];
  int _index = -1; // logical current index into _items
  int _loadedIndex = -1; // index actually pushed to the renderer
  bool _shuffle = false;
  bool _repeatAll = false;

  bool _playing = false;
  bool _advancing = false; // guards against double-advance while a track loads
  bool _confirmedPlaying = false; // renderer reached PLAYING for the current track
  bool _reachedNearEnd = false; // position reached end-of-track while playing
  Duration _position = Duration.zero;
  Duration? _duration;
  BackendProcessingState _state = BackendProcessingState.idle;

  Timer? _pollTimer;
  bool _polling = false;
  bool _disposed = false;

  final BehaviorSubject<int?> _indexSubject = BehaviorSubject<int?>.seeded(null);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject =
      BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<BackendProcessingState> _stateSubject =
      BehaviorSubject<BackendProcessingState>.seeded(
          BackendProcessingState.idle);
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  void _change() {
    if (!_changeController.isClosed) _changeController.add(null);
  }

  void _setState(BackendProcessingState s) {
    _state = s;
    if (!_stateSubject.isClosed) _stateSubject.add(s);
  }

  // ── Source list (mirrors just_audio's playlist API) ──
  @override
  Future<void> setSources(List<MediaItem> items) async {
    _items = List<MediaItem>.from(items);
    _index = _items.isEmpty ? -1 : 0;
    _loadedIndex = -1;
    _indexSubject.add(_index < 0 ? null : _index);
    _setState(_items.isEmpty
        ? BackendProcessingState.idle
        : BackendProcessingState.ready);
  }

  @override
  Future<void> addSource(MediaItem item) async {
    _items.add(item);
    if (_index == -1) {
      _index = 0;
      _indexSubject.add(0);
      _setState(BackendProcessingState.ready);
    }
  }

  @override
  Future<void> removeSourceAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    if (_items.isEmpty) {
      _index = -1;
      _loadedIndex = -1;
      _indexSubject.add(null);
      await _stopRenderer();
      _setState(BackendProcessingState.idle);
      return;
    }
    if (index < _index) {
      _index--;
      _loadedIndex--;
      _indexSubject.add(_index);
    }
  }

  @override
  Future<void> clearSources() async {
    _items = <MediaItem>[];
    _index = -1;
    _loadedIndex = -1;
    _indexSubject.add(null);
    await _stopRenderer();
    _setState(BackendProcessingState.idle);
  }

  // ── Transport ──
  // DLNA renderers fetch the URL themselves, so use the network id (not the
  // localPath download, which the renderer can't reach).
  Uri _uriFor(MediaItem item) => Uri.parse(item.id);

  AudioMetadata _metaFor(MediaItem item) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV.
    final art = castArtUrl(item);
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

  Future<void> _loadIndex(int index, {required bool play}) async {
    if (index < 0 || index >= _items.length) return;
    _index = index;
    _indexSubject.add(index);
    final item = _items[index];
    _confirmedPlaying = false;
    _reachedNearEnd = false;
    _setState(BackendProcessingState.loading);
    try {
      await _api.setMediaUri(
          _udn, Url(value: _uriFor(item).toString()), _metaFor(item));
      _loadedIndex = index;
      _duration = item.duration;
      _durationSubject.add(_duration);
      _position = Duration.zero;
      _positionSubject.add(_position);
      if (play) {
        await _api.play(_udn);
        _playing = true;
      }
      _setState(BackendProcessingState.ready);
      _startPolling();
    } catch (e) {
      // ignore: avoid_print
      print('DLNA load failed: $e');
    }
    _change();
  }

  @override
  Future<void> play() async {
    if (_index < 0) return;
    if (_loadedIndex != _index) {
      await _loadIndex(_index, play: true);
      return;
    }
    try {
      await _api.play(_udn);
    } catch (_) {}
    _playing = true;
    _setState(BackendProcessingState.ready);
    _startPolling();
    _change();
  }

  @override
  Future<void> pause() async {
    try {
      await _api.pause(_udn);
    } catch (_) {}
    _playing = false;
    _change();
  }

  @override
  Future<void> stop() async {
    await _stopRenderer();
    _playing = false;
    _setState(BackendProcessingState.idle);
    _change();
  }

  Future<void> _stopRenderer() async {
    _stopPolling();
    try {
      await _api.stop(_udn);
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    final target = index ?? _index;
    if (target >= 0 && target != _loadedIndex) {
      await _loadIndex(target, play: _playing);
    }
    try {
      await _api.seek(_udn, TimePosition(seconds: position.inSeconds));
    } catch (_) {}
    _position = position;
    _positionSubject.add(position);
    _change();
  }

  @override
  Future<void> seekToNext() async {
    final n = _nextIndex();
    if (n != null) await _loadIndex(n, play: _playing || _state == BackendProcessingState.ready);
  }

  @override
  Future<void> seekToPrevious() async {
    if (_index > 0) {
      await _loadIndex(_index - 1, play: _playing);
    } else {
      await seek(Duration.zero);
    }
  }

  int? _nextIndex() {
    if (_items.isEmpty) return null;
    if (_shuffle && _items.length > 1) {
      int n;
      do {
        n = _rng.nextInt(_items.length);
      } while (n == _index);
      return n;
    }
    if (_index + 1 < _items.length) return _index + 1;
    if (_repeatAll) return 0;
    return null;
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    _shuffle = enabled;
    _change();
  }

  @override
  Future<void> setRepeatAll(bool enabled) async {
    _repeatAll = enabled;
    _change();
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
      final info = await _api.getPlaybackInfo(_udn);
      _position = Duration(seconds: info.position.seconds);
      _positionSubject.add(_position);
      if (info.duration.seconds > 0) {
        _duration = Duration(seconds: info.duration.seconds);
        _durationSubject.add(_duration);
      }
      // Latch once we've genuinely reached the end while playing — robust to
      // renderers that reset position to 0 when they stop at track end.
      final dur = _duration;
      if (dur != null &&
          dur > Duration.zero &&
          _position >= dur - const Duration(seconds: 5)) {
        _reachedNearEnd = true;
      }
      switch (info.state) {
        case TransportState.playing:
          _playing = true;
          _advancing = false;
          _confirmedPlaying = true;
          _setState(BackendProcessingState.ready);
          break;
        case TransportState.paused:
          _playing = false;
          break;
        case TransportState.transitioning:
          _setState(BackendProcessingState.buffering);
          break;
        case TransportState.stopped:
          await _onRendererStopped();
          break;
        case TransportState.noMediaPresent:
          break;
      }
      _change();
    } catch (_) {
      // Transient renderer/network error — keep polling.
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
    final n = _nextIndex();
    if (n != null) {
      await _loadIndex(n, play: true); // _advancing cleared when poll sees PLAYING
    } else {
      _playing = false;
      _advancing = false;
      _setState(BackendProcessingState.completed);
      _stopPolling();
    }
  }

  // ── Synchronous state ──
  @override
  bool get playing => _playing;
  @override
  bool get shuffleEnabled => _shuffle;
  @override
  bool get repeatAll => _repeatAll;
  @override
  Duration get position => _position;
  @override
  Duration get bufferedPosition => _position; // DLNA exposes no buffer info
  @override
  double get speed => 1.0;
  @override
  Duration? get duration => _duration;
  @override
  int? get currentIndex => _index < 0 ? null : _index;
  @override
  BackendProcessingState get processingState => _state;

  // ── Streams ──
  @override
  Stream<int?> get currentIndexStream => _indexSubject.stream;
  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;
  @override
  Stream<BackendProcessingState> get processingStateStream =>
      _stateSubject.stream;
  @override
  Stream<void> get changeStream => _changeController.stream;

  // ── Local-only capabilities (N/A while casting) ──
  @override
  bool get supportsEqualizer => false;
  @override
  AndroidEqualizer? get equalizer => null;
  @override
  int? get androidAudioSessionId => null;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopPolling();
    await _stopRenderer();
    await _indexSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _stateSubject.close();
    await _changeController.close();
  }
}
