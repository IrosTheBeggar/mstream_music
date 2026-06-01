import 'dart:async';
import 'dart:math' show Random;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:just_audio/just_audio.dart' show AndroidEqualizer;
import 'package:rxdart/rxdart.dart';

import 'cast_art.dart';
import 'playback_backend.dart';

/// [PlaybackBackend] that plays through a Chromecast / Google Cast device via
/// the native Cast SDK (flutter_chrome_cast).
///
/// Like the DLNA backend it emulates just_audio's playlist (the receiver plays
/// one track at a time): it owns the source list + index, loads the current
/// track with the Remote Media Client, and advances when the receiver reports
/// IDLE with idleReason FINISHED. Unlike DLNA, the Cast SDK pushes position +
/// media-status via streams (no polling), and loadMedia takes autoPlay +
/// playPosition so resume-at-position is native.
class ChromecastPlaybackBackend implements PlaybackBackend {
  ChromecastPlaybackBackend({required String deviceId}) : _deviceId = deviceId;

  final String _deviceId;
  final Random _rng = Random();

  final _client = GoogleCastRemoteMediaClient.instance;
  final _sessions = GoogleCastSessionManager.instance;

  List<MediaItem> _items = <MediaItem>[];
  int _index = -1;
  int _loadedIndex = -1;
  bool _shuffle = false;
  bool _repeatAll = false;
  bool _playing = false;
  bool _advancing = false;
  bool _sessionStarted = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  BackendProcessingState _state = BackendProcessingState.idle;

  StreamSubscription<GoggleCastMediaStatus?>? _statusSub;
  StreamSubscription<Duration>? _positionSub;

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

  // isClosed-guarded emitters so a late async callback after dispose() can't
  // add to a closed subject.
  void _emitIndex(int? v) {
    if (!_indexSubject.isClosed) _indexSubject.add(v);
  }

  void _emitPos(Duration v) {
    if (!_positionSubject.isClosed) _positionSubject.add(v);
  }

  void _emitDur(Duration? v) {
    if (!_durationSubject.isClosed) _durationSubject.add(v);
  }

  void _change() {
    if (!_changeController.isClosed) _changeController.add(null);
  }

  void _setState(BackendProcessingState s) {
    _state = s;
    if (!_stateSubject.isClosed) _stateSubject.add(s);
  }

  void _ensureListeners() {
    _statusSub ??= _client.mediaStatusStream.listen(_onStatus);
    _positionSub ??= _client.playerPositionStream.listen((pos) {
      _position = pos;
      _emitPos(pos);
      _change();
    });
  }

  void _onStatus(GoggleCastMediaStatus? status) {
    if (status == null) return;
    final d = status.mediaInformation?.duration;
    if (d != null) {
      _duration = d;
      _emitDur(d);
    }
    switch (status.playerState) {
      case CastMediaPlayerState.playing:
        _playing = true;
        _advancing = false;
        _setState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.paused:
        _playing = false;
        _setState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.buffering:
        _setState(BackendProcessingState.buffering);
        break;
      case CastMediaPlayerState.loading:
        _setState(BackendProcessingState.loading);
        break;
      case CastMediaPlayerState.idle:
        // Only a natural FINISH means end-of-track; cancelled/interrupted are
        // our own load/stop transitions and must not trigger an advance.
        if (status.idleReason == GoogleCastMediaIdleReason.finished) {
          _onTrackEnded();
        }
        break;
      case CastMediaPlayerState.unknown:
        break;
    }
    _change();
  }

  Future<void> _onTrackEnded() async {
    if (_advancing) return;
    _advancing = true;
    final n = _nextIndex();
    if (n != null) {
      await _loadIndex(n, play: true);
    } else {
      _playing = false;
      _advancing = false;
      _setState(BackendProcessingState.completed);
    }
  }

  Future<void> _ensureSession() async {
    if (_sessionStarted && _sessions.hasConnectedSession) return;
    GoogleCastDevice? device;
    for (final d in GoogleCastDiscoveryManager.instance.devices) {
      if (d.deviceID == _deviceId) {
        device = d;
        break;
      }
    }
    if (device == null) {
      throw StateError('Chromecast device $_deviceId not found in discovery');
    }
    if (!_sessions.hasConnectedSession) {
      await _sessions.startSessionWithDevice(device);
      if (!_sessions.hasConnectedSession) {
        try {
          await _sessions.currentSessionStream
              .firstWhere((_) => _sessions.hasConnectedSession)
              .timeout(const Duration(seconds: 12));
        } catch (_) {
          // Proceed anyway; loadMedia will surface a failure if not connected.
        }
      }
    }
    _sessionStarted = true;
  }

  // ── Source list ──
  @override
  Future<void> setSources(List<MediaItem> items) async {
    _items = List<MediaItem>.from(items);
    _index = _items.isEmpty ? -1 : 0;
    _loadedIndex = -1;
    _emitIndex(_index < 0 ? null : _index);
    _setState(_items.isEmpty
        ? BackendProcessingState.idle
        : BackendProcessingState.ready);
  }

  @override
  Future<void> addSource(MediaItem item) async {
    _items.add(item);
    if (_index == -1) {
      _index = 0;
      _emitIndex(0);
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
      _emitIndex(null);
      await stop();
      return;
    }
    if (index < _index) {
      _index--;
      _loadedIndex--;
      _emitIndex(_index);
    } else if (index == _index) {
      // Removed the now-playing track — advance to whatever now occupies this
      // slot (the former next track), clamping if it was the last.
      if (_index >= _items.length) _index = _items.length - 1;
      _loadedIndex = -1;
      _emitIndex(_index);
      await _loadIndex(_index, play: _playing);
    }
  }

  @override
  Future<void> clearSources() async {
    _items = <MediaItem>[];
    _index = -1;
    _loadedIndex = -1;
    _emitIndex(null);
    await stop();
  }

  // ── Media construction ──
  Uri _uriFor(MediaItem item) => Uri.parse(item.id);

  String _mimeFor(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.flac')) return 'audio/flac';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.mp4')) return 'audio/mp4';
    if (path.endsWith('.ogg') || path.endsWith('.opus')) return 'audio/ogg';
    return 'audio/mpeg';
  }

  GoogleCastMediaInformation _mediaInfo(MediaItem item) {
    final url = _uriFor(item).toString();
    // Full-res art (drop the compress= size param) — looks sharp on a TV.
    final art = castArtUrl(item);
    return GoogleCastMediaInformation(
      contentId: url,
      contentUrl: Uri.parse(url),
      streamType: CastMediaStreamType.buffered,
      contentType: _mimeFor(url),
      duration: item.duration,
      metadata: GoogleCastMusicMediaMetadata(
        title: item.title,
        artist: item.artist,
        albumName: item.album,
        trackNumber: intExtra(item, 'track'),
        discNumber: intExtra(item, 'disc'),
        releaseDate: releaseDateFor(item),
        images: art != null ? [GoogleCastImage(url: Uri.parse(art))] : null,
      ),

    );
  }

  Future<void> _loadIndex(int index,
      {required bool play, Duration startAt = Duration.zero}) async {
    if (index < 0 || index >= _items.length) return;
    _index = index;
    _emitIndex(index);
    _setState(BackendProcessingState.loading);
    try {
      await _ensureSession();
      _ensureListeners();
      await _client.loadMedia(_mediaInfo(_items[index]),
          autoPlay: play, playPosition: startAt);
      _loadedIndex = index;
      _playing = play;
      _duration = _items[index].duration;
      _emitDur(_duration);
      _position = startAt;
      _emitPos(startAt);
    } catch (e) {
      // ignore: avoid_print
      print('Chromecast load failed: $e');
    }
    _change();
  }

  // ── Transport ──
  @override
  Future<void> play() async {
    if (_index < 0) return;
    if (_loadedIndex != _index) {
      await _loadIndex(_index, play: true);
      return;
    }
    try {
      await _client.play();
    } catch (_) {}
    _playing = true;
    _change();
  }

  @override
  Future<void> pause() async {
    try {
      await _client.pause();
    } catch (_) {}
    _playing = false;
    _change();
  }

  @override
  Future<void> stop() async {
    try {
      await _client.stop();
    } catch (_) {}
    _playing = false;
    _setState(BackendProcessingState.idle);
    _change();
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    final target = index ?? _index;
    if (target >= 0 && target != _loadedIndex) {
      await _loadIndex(target, play: _playing, startAt: position);
      return;
    }
    try {
      await _client.seek(GoogleCastMediaSeekOption(position: position));
    } catch (_) {}
    _position = position;
    _emitPos(position);
    _change();
  }

  @override
  Future<void> seekToNext() async {
    final n = _nextIndex();
    if (n != null) await _loadIndex(n, play: _playing);
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
      _sessions.setDeviceVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
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
  Duration get bufferedPosition => _position;
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
    await _statusSub?.cancel();
    await _positionSub?.cancel();
    try {
      await _sessions.endSessionAndStopCasting();
    } catch (_) {}
    await _indexSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _stateSubject.close();
    await _changeController.close();
  }
}
