import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../native/visualizer_bridge.dart';
import '../singletons/cast_manager.dart';
import '../singletons/settings.dart';
import 'cast_art.dart';
import 'cast_log.dart';
import 'emulated_playlist_backend.dart';
import 'local_media_server.dart';
import 'playback_backend.dart';
import 'visualizer_cast_config.dart';

/// [PlaybackBackend] that plays through a Chromecast / Google Cast device via
/// the native Cast SDK (flutter_chrome_cast).
///
/// Like the DLNA backend it emulates just_audio's playlist through
/// [EmulatedPlaylistBackend] (the receiver plays one track at a time): the base
/// owns the source list + index + the add/remove/move/clear arithmetic and the
/// broadcast streams; this subclass loads the current track with the Remote
/// Media Client and advances when the receiver reports IDLE with idleReason
/// FINISHED. Unlike DLNA, the Cast SDK pushes position + media-status via
/// streams (no polling), and loadMedia takes autoPlay + playPosition so
/// resume-at-position is native.
class ChromecastPlaybackBackend extends EmulatedPlaylistBackend {
  ChromecastPlaybackBackend({required this._deviceId, this._visualizer = false});

  final String _deviceId;
  // When true, cast the on-device visualizer transcoded to HLS video instead of
  // the track's audio (see _resolveVisualizerUri). Only the per-track media
  // construction differs — the playlist/index/session/transport logic is shared.
  final bool _visualizer;

  final _client = GoogleCastRemoteMediaClient.instance;
  final _sessions = GoogleCastSessionManager.instance;

  int _loadCounter = 0; // monotonic; names each visualizer transcode's subdir
  String? _currentVizDir; // subdir the active visualizer transcode writes to
  bool _firstVizLoad = true;
  int _visualizerFailures = 0; // consecutive transcode failures → audio fallback
  // Bumped on every loadIndex; an in-flight load re-checks it after each await
  // and bails if a newer load superseded it. The visualizer warm-up is seconds
  // long, so a Next/seek during it would otherwise interleave two loads and
  // leave the wrong track casting.
  int _loadGen = 0;

  // Give up re-attempting the visualizer after this many *consecutive* failures
  // (a single transient failure still retries on the next track).
  static const int _kMaxVisualizerFailures = 2;
  // Readiness poll: 20 × 500 ms = 10 s for the first segments before giving up.
  static const int _kReadyPollAttempts = 20;

  bool _advancing = false;
  bool _sessionStarted = false;

  StreamSubscription<GoggleCastMediaStatus?>? _statusSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<dynamic>? _sessionSub;

  // Guards the renderer-lost emit. _disposing suppresses our own teardown;
  // _lostFired makes it one-shot (disconnecting → disconnected would otherwise
  // emit twice).
  bool _disposing = false;
  bool _lostFired = false;

  void _ensureListeners() {
    _statusSub ??= _client.mediaStatusStream.listen(_onStatus);
    _positionSub ??= _client.playerPositionStream.listen((pos) {
      position = pos;
      emitPos(pos);
      change();
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
        emitRendererLost(
            'Lost connection to the cast device — back on this phone');
      }
    });
  }

  void _onStatus(GoggleCastMediaStatus? status) {
    if (status == null) return;
    final d = status.mediaInformation?.duration;
    if (d != null) {
      duration = d;
      emitDur(d);
    }
    switch (status.playerState) {
      case CastMediaPlayerState.playing:
        playing = true;
        _advancing = false;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.paused:
        playing = false;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.buffering:
        setProcessingState(BackendProcessingState.buffering);
        break;
      case CastMediaPlayerState.loading:
        setProcessingState(BackendProcessingState.loading);
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
    change();
  }

  Future<void> _onTrackEnded() async {
    if (_advancing) return;
    _advancing = true;
    final n = nextIndex(onComplete: true);
    if (n != null) {
      await loadIndex(n, play: true);
    } else {
      playing = false;
      _advancing = false;
      setProcessingState(BackendProcessingState.completed);
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

  @protected
  @override
  Future<void> loadIndex(int target,
      {required bool play, Duration startAt = Duration.zero}) async {
    if (target < 0 || target >= items.length) return;
    final gen = ++_loadGen; // this load owns the pipeline until a newer one starts
    index = target;
    emitIndex(target);
    setProcessingState(BackendProcessingState.loading);
    try {
      await _ensureSession();
      if (gen != _loadGen) return; // superseded by a newer load
      _ensureListeners();
      // True only when this load actually served the visualizer (vs audio or
      // the audio fallback below) — drives the start position emitted after.
      var servedVisualizer = false;
      if (_visualizer && _visualizerFailures < _kMaxVisualizerFailures) {
        try {
          // A freshly-started live transcode begins at 0; seeking into it isn't
          // possible, so startAt is ignored for the visualizer.
          final url =
              (await _resolveVisualizerUri(items[target], gen)).toString();
          if (gen != _loadGen) return; // superseded during the warm-up
          await _client.loadMedia(_visualizerMediaInfo(items[target], url),
              autoPlay: play);
          servedVisualizer = true;
          _visualizerFailures = 0; // recovered — a transient failure won't stick
        } catch (e) {
          if (gen != _loadGen) return; // superseded, not a real failure
          // Transcode/render failed — don't strand the cast on the phone; keep
          // the music on the TV as plain audio and tell the user. After a couple
          // of consecutive failures we stop re-attempting (avoids repeated waits).
          castLog('Visualizer cast failed; casting audio instead', error: e);
          _visualizerFailures++;
          try {
            await VisualizerBridge.stopTranscode();
          } catch (_) {}
          _deleteDir(_currentVizDir);
          CastManager().reportCastInfo(
              "Couldn't start the visualizer — casting audio to the TV");
          final url = (await _resolveUri(items[target])).toString();
          if (gen != _loadGen) return;
          await _client.loadMedia(_mediaInfo(items[target], url),
              autoPlay: play, playPosition: startAt);
        }
      } else {
        final url = (await _resolveUri(items[target])).toString();
        if (gen != _loadGen) return;
        await _client.loadMedia(_mediaInfo(items[target], url),
            autoPlay: play, playPosition: startAt);
      }
      if (gen != _loadGen) return;
      loadedIndex = target;
      playing = play;
      duration = items[target].duration;
      emitDur(duration);
      position = servedVisualizer ? Duration.zero : startAt;
      emitPos(position);
    } catch (e) {
      castLog('Chromecast load failed', error: e);
    }
    change();
  }

  // ── Visualizer cast ──
  // Transcode the current track to an HLS video of the app's visualizer
  // reacting to it (rendered on-device), serve it from LocalMediaServer, and
  // return the playlist URL for the receiver. One transcode at a time — each
  // call cancels the previous track's first, so track-change (which routes
  // through loadIndex) restarts the pipeline cleanly. Blocks until a couple of
  // segments exist so the receiver never loads an empty playlist.
  Future<Uri> _resolveVisualizerUri(MediaItem item, int gen) async {
    _loadCounter++;
    await VisualizerBridge.stopTranscode(); // stop the previous track's, if any
    if (gen != _loadGen) throw StateError('superseded');
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
    if (gen != _loadGen) throw StateError('superseded');
    final quality = SettingsManager().castVisualizerQuality;
    final playlist = await VisualizerBridge.startTranscode(
      source: source,
      output: dir,
      preset: cfg.preset,
      engine: cfg.engine,
      // Resolution from the user's Cast quality setting (default 1080p). The
      // visualizer draws into the encoder at this size, so render AND encode
      // scale together; VideoEncoder scales bitrate to match.
      width: quality.width,
      height: quality.height,
      maxMs: 0, // whole track
      tuning: cfg.tuning,
    );
    if (playlist == null) {
      throw StateError('visualizer transcode failed to start');
    }
    // Wait (up to ~10 s) for two segments before pointing the receiver at it; if
    // they never arrive the transcode is wedged — fail so the handler falls back
    // instead of casting an empty playlist. Async I/O so the poll doesn't block
    // the UI isolate.
    final plFile = File('$dir/index.m3u8');
    var ready = false;
    for (var i = 0; i < _kReadyPollAttempts && !ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (gen != _loadGen) throw StateError('superseded');
      try {
        // Count #EXTINF tags — one per segment — rather than '.ts' substrings,
        // which would also match anything else in the playlist ending in .ts.
        if (await plFile.exists() &&
            '#EXTINF'.allMatches(await plFile.readAsString()).length >= 2) {
          ready = true;
        }
      } catch (_) {/* mid-write / not ready yet — try again */}
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
      contentType:
          'application/vnd.apple.mpegurl', // HLS (IANA type; matches LocalMediaServer)
      metadata: GoogleCastGenericMediaMetadata(
        title: item.title,
        subtitle: item.artist,
      ),
    );
  }

  // ── Transport ──
  @override
  Future<void> play() async {
    if (index < 0) return;
    if (loadedIndex != index) {
      await loadIndex(index, play: true);
      return;
    }
    try {
      await _client.play();
    } catch (_) {}
    playing = true;
    change();
  }

  @override
  Future<void> pause() async {
    try {
      await _client.pause();
    } catch (_) {}
    playing = false;
    change();
  }

  @override
  Future<void> stop() async {
    try {
      await _client.stop();
    } catch (_) {}
    playing = false;
    setProcessingState(BackendProcessingState.idle);
    change();
  }

  @protected
  @override
  Future<void> stopForEmptyList() => stop();

  @override
  Future<void> seek(Duration position, {int? index, bool? play}) async {
    final target = index ?? this.index;
    if (target >= 0 && target != loadedIndex) {
      await loadIndex(target, play: play ?? playing, startAt: position);
      return;
    }
    try {
      await _client.seek(GoogleCastMediaSeekOption(position: position));
    } catch (_) {}
    this.position = position;
    emitPos(position);
    change();
  }

  @override
  Future<void> seekToNext() async {
    final n = nextIndex();
    if (n != null) await loadIndex(n, play: playing);
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
      _sessions.setDeviceVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  @protected
  @override
  Future<void> disposeRenderer() async {
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
  }
}
