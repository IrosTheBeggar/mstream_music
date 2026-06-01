import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:math' show Random;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:just_audio/just_audio.dart' show AndroidEqualizer;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../native/visualizer_bridge.dart';
import '../singletons/cast_manager.dart';
import 'cast_art.dart';
import 'cast_log.dart';
import 'local_media_server.dart';
import 'playback_backend.dart';
import 'visualizer_cast_config.dart';

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
  ChromecastPlaybackBackend({required String deviceId, bool visualizer = false})
      : _deviceId = deviceId,
        _visualizer = visualizer;

  final String _deviceId;
  // When true, cast the on-device visualizer transcoded to HLS video instead of
  // the track's audio (see _resolveVisualizerUri). Only the per-track media
  // construction differs — the playlist/index/session/transport logic is shared.
  final bool _visualizer;
  final Random _rng = Random();

  final _client = GoogleCastRemoteMediaClient.instance;
  final _sessions = GoogleCastSessionManager.instance;

  List<MediaItem> _items = <MediaItem>[];
  int _index = -1;
  int _loadedIndex = -1;
  int _loadCounter = 0; // monotonic; names each visualizer transcode's subdir
  String? _currentVizDir; // subdir the active visualizer transcode writes to
  bool _firstVizLoad = true;
  bool _visualizerFellBack = false; // latched once a transcode fails → audio
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
  StreamSubscription<dynamic>? _sessionSub;

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
  // Emits when the Cast session drops unexpectedly mid-cast; the handler falls
  // back to local. _disposing suppresses our own teardown; _lostFired makes it
  // one-shot (disconnecting → disconnected would otherwise emit twice).
  final PublishSubject<String> _rendererLost = PublishSubject<String>();
  bool _disposing = false;
  bool _lostFired = false;

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
    // Detect an unexpected session drop (TV off, Wi-Fi lost). Listeners attach
    // only after _ensureSession connected (_sessionStarted), so a transition to
    // not-connected we didn't initiate means the renderer is gone.
    _sessionSub ??= _sessions.currentSessionStream.listen((_) {
      if (_sessionStarted &&
          !_disposing &&
          !_lostFired &&
          !_sessions.hasConnectedSession) {
        _lostFired = true;
        if (!_rendererLost.isClosed) {
          _rendererLost
              .add('Lost connection to the cast device — back on this phone');
        }
      }
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
  // A network id (server URL) is sent as-is; a local-only item (file-explorer
  // track — id is a UUID) is served from the phone's LocalMediaServer so the
  // receiver can reach it.
  Future<Uri> _resolveUri(MediaItem item) async {
    final localPath = item.extras?['localPath'] as String?;
    final isNetwork =
        item.id.startsWith('http://') || item.id.startsWith('https://');
    if (!isNetwork && localPath != null && File(localPath).existsSync()) {
      await LocalMediaServer().ensureStarted();
      return LocalMediaServer().registerFile(localPath);
    }
    return Uri.parse(item.id);
  }

  GoogleCastMediaInformation _mediaInfo(MediaItem item, String url) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV.
    final art = castArtUrl(item);
    return GoogleCastMediaInformation(
      contentId: url,
      contentUrl: Uri.parse(url),
      streamType: CastMediaStreamType.buffered,
      contentType: mimeForPath(url),
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
      // True only when this load actually served the visualizer (vs audio or
      // the audio fallback below) — drives the start position emitted after.
      var servedVisualizer = false;
      if (_visualizer && !_visualizerFellBack) {
        try {
          // A freshly-started live transcode begins at 0; seeking into it isn't
          // possible, so startAt is ignored for the visualizer.
          final url = (await _resolveVisualizerUri(_items[index])).toString();
          await _client.loadMedia(_visualizerMediaInfo(_items[index], url),
              autoPlay: play);
          servedVisualizer = true;
        } catch (e) {
          // Transcode/render failed — don't strand the cast on the phone; keep
          // the music on the TV as plain audio and tell the user. Latched so we
          // don't re-attempt (and re-fail) the visualizer on every later track.
          castLog('Visualizer cast failed; casting audio instead', error: e);
          _visualizerFellBack = true;
          try {
            await VisualizerBridge.stopTranscode();
          } catch (_) {}
          _deleteDir(_currentVizDir);
          CastManager().reportCastInfo(
              "Couldn't start the visualizer — casting audio to the TV");
          final url = (await _resolveUri(_items[index])).toString();
          await _client.loadMedia(_mediaInfo(_items[index], url),
              autoPlay: play, playPosition: startAt);
        }
      } else {
        final url = (await _resolveUri(_items[index])).toString();
        await _client.loadMedia(_mediaInfo(_items[index], url),
            autoPlay: play, playPosition: startAt);
      }
      _loadedIndex = index;
      _playing = play;
      _duration = _items[index].duration;
      _emitDur(_duration);
      _position = servedVisualizer ? Duration.zero : startAt;
      _emitPos(_position);
    } catch (e) {
      castLog('Chromecast load failed', error: e);
    }
    _change();
  }

  // ── Visualizer cast ──
  // Transcode the current track to an HLS video of the app's visualizer
  // reacting to it (rendered on-device), serve it from LocalMediaServer, and
  // return the playlist URL for the receiver. One transcode at a time — each
  // call cancels the previous track's first, so track-change (which routes
  // through _loadIndex) restarts the pipeline cleanly. Blocks until a couple of
  // segments exist so the receiver never loads an empty playlist.
  Future<Uri> _resolveVisualizerUri(MediaItem item) async {
    _loadCounter++;
    await VisualizerBridge.stopTranscode(); // stop the previous track's, if any
    final parent = await _visualizerParentDir();
    // Each track transcodes into its OWN subdirectory, so a just-stopped
    // previous transcode can never race the new one on the same files. Keep disk
    // bounded: on the first load drop any prior session's tree; on later loads
    // drop the previous track's (its transcode is stopped above, and in the
    // common track-change case had already finished).
    if (_firstVizLoad) {
      _firstVizLoad = false;
      _deleteDir(parent);
    } else {
      _deleteDir(_currentVizDir);
    }
    final dir = '$parent/$_loadCounter';
    _currentVizDir = dir;

    final source = (item.extras?['localPath'] as String?) ?? item.id;
    final cfg = await resolveVisualizerCastConfig();
    final playlist = await VisualizerBridge.startTranscode(
      source: source,
      output: dir,
      preset: cfg.preset,
      engine: cfg.engine,
      maxMs: 0, // whole track
      tuning: cfg.tuning,
      mode: 'hls',
    );
    if (playlist == null) {
      throw StateError('visualizer transcode failed to start');
    }
    // Wait (up to ~20 s) for two segments before pointing the receiver at it; if
    // they never arrive the transcode is wedged — fail so the handler falls back
    // instead of casting an empty playlist.
    final plFile = File('$dir/index.m3u8');
    var ready = false;
    for (var i = 0; i < 40 && !ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (plFile.existsSync() &&
          '.ts'.allMatches(plFile.readAsStringSync()).length >= 2) {
        ready = true;
      }
    }
    if (!ready) {
      throw StateError('visualizer stream not ready');
    }
    await LocalMediaServer().ensureStarted();
    // A fresh subdir per track means a fresh URL/token, so the receiver always
    // re-reads the new playlist (no cache-busting query needed).
    return LocalMediaServer().registerDirectory(dir);
  }

  Future<String> _visualizerParentDir() async {
    final base = await getExternalStorageDirectory();
    if (base == null) {
      throw StateError('No external storage for visualizer cast');
    }
    return '${base.path}/viz_cast';
  }

  void _deleteDir(String? path) {
    if (path == null) return;
    try {
      final d = Directory(path);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
  }

  GoogleCastMediaInformation _visualizerMediaInfo(MediaItem item, String url) {
    return GoogleCastMediaInformation(
      contentId: url,
      contentUrl: Uri.parse(url),
      streamType: CastMediaStreamType.buffered,
      contentType: 'application/x-mpegurl', // HLS (validated on the receiver)
      metadata: GoogleCastGenericMediaMetadata(
        title: item.title,
        subtitle: item.artist,
      ),
    );
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

  @override
  Stream<String> get rendererLostStream => _rendererLost.stream;

  // ── Local-only capabilities (N/A while casting) ──
  @override
  bool get supportsEqualizer => false;
  @override
  AndroidEqualizer? get equalizer => null;
  @override
  int? get androidAudioSessionId => null;

  @override
  Future<void> dispose() async {
    _disposing = true;
    if (_visualizer) {
      // Stop the off-screen transcode so it isn't left encoding after we switch
      // away. (LocalMediaServer is torn down by the handler on switch-to-local.)
      try {
        await VisualizerBridge.stopTranscode();
      } catch (_) {}
      _deleteDir(_currentVizDir); // drop the last track's segments
    }
    await _statusSub?.cancel();
    await _positionSub?.cancel();
    await _sessionSub?.cancel();
    try {
      await _sessions.endSessionAndStopCasting();
    } catch (_) {}
    await _indexSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _stateSubject.close();
    await _changeController.close();
    await _rendererLost.close();
  }
}
