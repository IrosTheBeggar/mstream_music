import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../native/visualizer_bridge.dart';
import '../singletons/cast_manager.dart';
import '../singletons/log_manager.dart';
import '../singletons/settings.dart';
import 'cast_art.dart';
import 'cast_log.dart';
import 'cast_origin.dart';
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

  bool _sessionStarted = false;

  StreamSubscription<GoggleCastMediaStatus?>? _statusSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<dynamic>? _sessionSub;

  // Guards the renderer-lost emit. _disposing suppresses our own teardown;
  // _lostFired makes it one-shot per drop (disconnecting → disconnected would
  // otherwise emit twice); it re-arms when the session reconnects.
  bool _disposing = false;
  bool _lostFired = false;

  // Grace timer for a not-connected session: the Cast SDK SUSPENDS a session
  // on a transient network blip and auto-resumes it (the receiver keeps
  // playing from its buffer), so tearing down immediately would turn a
  // 3-second Wi-Fi blip into a dead cast. A session that ENDS outright
  // (stream payload null) gets no grace — nothing will resume it.
  //
  // The grace must not expire while the PHONE ITSELF has no network: the blip
  // that suspended the session usually took our connectivity too, and the SDK
  // cannot resume until it returns (Wi-Fi reassociation alone can exceed any
  // sane fixed window — verified on-device: a 5s blip took ~20s end to end).
  // While offline, the window re-arms instead of firing, bounded by
  // _kMaxGraceExtensions so a genuinely dead session still falls back.
  Timer? _sessionLossGrace;
  int _graceExtensions = 0;
  bool _graceWasOffline = false;
  static const Duration _kSessionLossGrace = Duration(seconds: 10);
  static const int _kMaxGraceExtensions = 8; // ≈90s worst case, offline only

  // Set via prepareCastToCastHandoff when the backend replacing this one is
  // also a Chromecast backend — teardown then leaves the shared session (and,
  // when the successor casts the visualizer, the global transcode pipeline)
  // to the successor instead of destroying what it is already using.
  bool _keepSharedSession = false;
  bool _handoffToVisualizer = false;

  /// Called by the handler before disposing this backend on a Chromecast →
  /// Chromecast switch (device change or visualizer toggle). The Cast SDK
  /// holds ONE session per app, shared by every backend instance through the
  /// singleton session manager — ending it in [disposeRenderer] would stop
  /// the session the successor just loaded media on. Likewise the visualizer
  /// transcode pipeline is global: when the successor runs the visualizer,
  /// its own first load already stopped ours and started its own, so stopping
  /// "the" transcode here would cut the successor's stream.
  void prepareCastToCastHandoff(ChromecastPlaybackBackend next) {
    _keepSharedSession = true;
    _handoffToVisualizer = next._visualizer;
  }

  // ── Silent-death watchdog ──
  // A sender-side network blip can sever the session with NO SessionManager
  // event at all (observed on-device: no suspend, no null — the SDK's
  // heartbeat takes minutes to notice, if ever, while the app sits 'playing'
  // with a frozen position). While the receiver plays, status/position events
  // tick ~every second — prolonged silence IS the failure signal (verified:
  // the progress listener genuinely stops on a dead session, it is not
  // interpolated locally). Mirrors the DLNA backend's poll-failure detection.
  Timer? _staleTicker;
  DateTime _lastRendererEvent = DateTime.now();
  bool _reattaching = false;
  static const Duration _kStaleAfter = Duration(seconds: 20);

  void _noteRendererEvent() => _lastRendererEvent = DateTime.now();

  Future<void> _checkStale() async {
    if (_disposing || _lostFired || _reattaching || !playing) return;
    if (DateTime.now().difference(_lastRendererEvent) < _kStaleAfter) return;
    _reattaching = true;
    try {
      appLog('[cast] no renderer events for ${_kStaleAfter.inSeconds}s '
          'while playing — probing the session');
      if (!await _hasLanNetwork()) {
        // Same as an offline session drop: wait out the LAN via the grace loop.
        _graceWasOffline = true;
        _sessionLossGrace ??= Timer(_kSessionLossGrace, _onGraceExpired);
        return;
      }
      if (await _tryReattach()) {
        appLog('[cast] re-attached after a silent session loss');
        return;
      }
      _fireRendererLost();
    } finally {
      _reattaching = false;
    }
  }

  void _ensureListeners() {
    _staleTicker ??=
        Timer.periodic(const Duration(seconds: 5), (_) => _checkStale());
    _statusSub ??= _client.mediaStatusStream.listen(_onStatus);
    _positionSub ??= _client.playerPositionStream.listen((pos) {
      _noteRendererEvent();
      position = pos;
      emitPos(pos);
      change();
    });
    // Detect an unexpected session drop (TV off, Wi-Fi lost). Listeners attach
    // only after _ensureSession connected (_sessionStarted), so a transition to
    // not-connected we didn't initiate means the renderer is gone — after the
    // suspend grace above, in case the SDK resumes it.
    _sessionSub ??= _sessions.currentSessionStream.listen((session) {
      if (_disposing || !_sessionStarted) return;
      if (_sessions.hasConnectedSession) {
        // (Re)connected — a suspended session resumed. Cancel any pending
        // loss and re-arm one-shot detection for the next drop.
        if (_sessionLossGrace != null) {
          appLog('[cast] session resumed within the grace window');
        }
        _sessionLossGrace?.cancel();
        _sessionLossGrace = null;
        _graceExtensions = 0;
        _graceWasOffline = false;
        _lostFired = false;
        return;
      }
      if (_lostFired) return;
      if (session == null) {
        // On Android a NETWORK drop surfaces as a full session END (a null
        // push), not a suspend — verified on-device. Probe connectivity
        // before believing it: while offline the "end" is just our own dead
        // network, so it gets the reconnect grace + re-attach like a suspend.
        // A null while online is a genuine end (TV quit) — fall back now.
        unawaited(_onSessionEnded());
        return;
      }
      _sessionLossGrace ??= Timer(_kSessionLossGrace, _onGraceExpired);
    });
  }

  Future<void> _onSessionEnded() async {
    final lanUp = await _hasLanNetwork();
    if (_disposing || _lostFired || _sessions.hasConnectedSession) return;
    if (lanUp) {
      _fireRendererLost();
      return;
    }
    _graceWasOffline = true;
    _sessionLossGrace ??= Timer(_kSessionLossGrace, _onGraceExpired);
  }

  Future<void> _onGraceExpired() async {
    // cancel() too, not just null: the session listener can have armed a FRESH
    // timer in the gap between this one firing and this handler running —
    // dropping that reference without cancelling would leave an orphan timer
    // double-driving this handler.
    _sessionLossGrace?.cancel();
    _sessionLossGrace = null;
    if (_disposing || _lostFired || _sessions.hasConnectedSession) return;
    if (_graceExtensions < _kMaxGraceExtensions) {
      if (!await _hasLanNetwork()) {
        // The LAN is still down — neither the SDK nor we can reach the
        // renderer yet.
        _graceExtensions++;
        _graceWasOffline = true;
        _sessionLossGrace = Timer(_kSessionLossGrace, _onGraceExpired);
        return;
      }
      if (_graceWasOffline) {
        // The network came back since the last check. The SDK auto-resumes a
        // SUSPENDED session from here (give it the window below) — but a
        // network drop that surfaced as an END won't resume on its own, so
        // actively re-attach: rejoin (or relaunch) the receiver and pick
        // playback back up. The receiver keeps playing through a sender-side
        // drop, so a successful rejoin is usually seamless.
        _graceExtensions++;
        if (await _tryReattach()) {
          appLog('[cast] re-attached to the cast device after a network drop');
          _graceWasOffline = false;
          _graceExtensions = 0;
          return;
        }
        if (_sessions.hasConnectedSession) return; // SDK resumed meanwhile
        // Not yet (device not re-discovered / session won't start) — another
        // window, bounded by the extension budget.
        _sessionLossGrace?.cancel();
        _sessionLossGrace = Timer(_kSessionLossGrace, _onGraceExpired);
        return;
      }
    }
    _fireRendererLost();
  }

  // Rebuild the session after a network-drop END and pick playback back up.
  // If the rejoined receiver reports our media still going (first FRESH
  // status — skip(1) bypasses the stream's stale replayed value), adopt it
  // as-is: the status/position streams resume driving state with no audible
  // hiccup. Otherwise (receiver relaunched idle / nothing arrives) reload the
  // current track at the last known position.
  Future<bool> _tryReattach() async {
    try {
      _sessionStarted = false; // force _ensureSession to re-connect
      await _ensureSession();
      if (!_sessions.hasConnectedSession) return false;
      _lostFired = false;
      GoggleCastMediaStatus? fresh;
      try {
        fresh = await _client.mediaStatusStream
            .skip(1)
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      final alive = fresh?.playerState == CastMediaPlayerState.playing ||
          fresh?.playerState == CastMediaPlayerState.buffering;
      if (!alive) {
        if (_sessions.hasConnectedSession) {
          // The session claims connected but delivers nothing — a half-dead
          // socket the SDK hasn't noticed. Force a genuinely fresh session
          // before reloading, or the loadMedia below goes into the same void.
          try {
            await _sessions.endSessionAndStopCasting();
          } catch (_) {}
          _sessionStarted = false;
          await _ensureSession();
          if (!_sessions.hasConnectedSession) return false;
        }
        final ok = await loadIndex(index, play: playing, startAt: position);
        if (!ok) return false;
      }
      return true;
    } catch (e) {
      castLog('cast re-attach failed', error: e);
      return false;
    }
  }

  // Is a LAN-capable transport (Wi-Fi / ethernet) up right now? A cast session
  // lives on the LAN, so "any connectivity" is the wrong question: when Wi-Fi
  // blips, the phone fails over to MOBILE DATA within seconds and a generic
  // probe reports online — which made a null-session during a Wi-Fi blip look
  // like a genuine end (verified on-device). Best-effort: a failed probe
  // counts as online so the grace can't extend forever on a broken probe.
  Future<bool> _hasLanNetwork() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return true;
    }
  }

  void _fireRendererLost() {
    _sessionLossGrace?.cancel();
    _sessionLossGrace = null;
    _lostFired = true;
    appLog('[cast] session lost (grace exhausted: $_graceExtensions '
        'extensions) — falling back to this phone');
    emitRendererLost('Lost connection to the cast device — back on this phone');
  }

  void _onStatus(GoggleCastMediaStatus? status) {
    _noteRendererEvent();
    if (status == null) return;
    final d = status.mediaInformation?.duration;
    if (d != null) {
      duration = d;
      emitDur(d);
    }
    switch (status.playerState) {
      case CastMediaPlayerState.playing:
        playing = true;
        trackPlaying();
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
        // A natural FINISH advances. ERROR means the receiver couldn't fetch
        // or decode the track (server blip, proxy 502, bad media) — walk on,
        // bounded, instead of leaving the TV silent with the state stuck on
        // 'playing'. cancelled/interrupted are our own load/stop transitions
        // and must not trigger anything.
        if (status.idleReason == GoogleCastMediaIdleReason.finished) {
          advanceOnComplete();
        } else if (status.idleReason == GoogleCastMediaIdleReason.error) {
          playing = false;
          trackFailed('receiver reported a media error');
        }
        break;
      case CastMediaPlayerState.unknown:
        break;
    }
    change();
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
    if (_sessions.hasConnectedSession &&
        _sessions.currentSession?.device?.deviceID != _deviceId) {
      // The existing session is on a DIFFERENT Chromecast (cast→cast device
      // switch). The SDK holds one session per app, so it must be moved —
      // reusing it would keep casting to the old device.
      try {
        await _sessions.endSessionAndStopCasting();
      } catch (e) {
        castLog('Ending the previous cast session failed', error: e);
      }
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
  // A plain HTTP server id is sent as-is; a local-only item (file-explorer track
  // — id is a UUID) is served from the phone's LocalMediaServer; an iroh server's
  // id is the phone-loopback tunnel URL the receiver can't reach, so it's relayed
  // through the LocalMediaServer proxy (re-bound to the live tunnel).
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

  GoogleCastMediaInformation _mediaInfo(MediaItem item, String url) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV; for an
    // iroh server it's relayed through the LAN proxy (LocalMediaServer already
    // started by _resolveUri above) so the receiver can fetch it.
    final art = castArtUriFor(item);
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
  Future<bool> loadIndex(int target,
      {required bool play, Duration startAt = Duration.zero}) async {
    if (target < 0 || target >= items.length) return false;
    final gen = ++_loadGen; // this load owns the pipeline until a newer load starts
    index = target;
    emitIndex(target);
    // A load (visualizer warm-up especially) legitimately produces no renderer
    // events for many seconds — restart the staleness clock.
    _noteRendererEvent();
    setProcessingState(BackendProcessingState.loading);
    try {
      await _ensureSession();
      // Superseded by a newer load: not a failure — the newer load owns the
      // renderer now, so report success and let it drive the state.
      if (gen != _loadGen) return true;
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
          if (gen != _loadGen) return true; // superseded during the warm-up
          await _client.loadMedia(_visualizerMediaInfo(items[target], url),
              autoPlay: play);
          servedVisualizer = true;
          _visualizerFailures = 0; // recovered — a transient failure won't stick
        } catch (e) {
          if (gen != _loadGen) return true; // superseded, not a real failure
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
          if (gen != _loadGen) return true;
          await _client.loadMedia(_mediaInfo(items[target], url),
              autoPlay: play, playPosition: startAt);
        }
      } else {
        final url = (await _resolveUri(items[target])).toString();
        if (gen != _loadGen) return true;
        await _client.loadMedia(_mediaInfo(items[target], url),
            autoPlay: play, playPosition: startAt);
      }
      if (gen != _loadGen) return true;
      loadedIndex = target;
      playing = play;
      duration = items[target].duration;
      emitDur(duration);
      position = servedVisualizer ? Duration.zero : startAt;
      emitPos(position);
    } catch (e) {
      castLog('Chromecast load failed', error: e);
      change();
      return false;
    }
    change();
    return true;
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

    // The transcoder reads this source on-device. A downloaded track is read
    // straight from disk; otherwise, for an iroh server, item.id is a stored
    // loopback URL whose port/token may have gone stale — re-origin to the live
    // tunnel (loopback IS reachable on the phone, so no LAN proxy is needed for
    // the transcoder's own input, only for the renderer's HLS pull).
    final localPath = item.extras?['localPath'] as String?;
    final String source;
    if (localPath != null && File(localPath).existsSync()) {
      source = localPath;
    } else {
      final iroh = irohServerFor(item);
      source =
          iroh != null ? irohLoopbackUri(iroh, item.id).toString() : item.id;
    }
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
    _sessionLossGrace?.cancel();
    _staleTicker?.cancel();
    if (_visualizer && !_handoffToVisualizer) {
      // Stop the off-screen transcode so it isn't left encoding after we switch
      // away. (LocalMediaServer is torn down by the handler on switch-to-local.)
      // Skipped on a handoff to another visualizer backend, whose first load
      // already stopped ours and now owns the global pipeline.
      try {
        await VisualizerBridge.stopTranscode();
      } catch (_) {}
      _deleteDir(_currentVizDir); // drop the last track's segments
    }
    await _statusSub?.cancel();
    await _positionSub?.cancel();
    await _sessionSub?.cancel();
    if (!_keepSharedSession) {
      try {
        await _sessions.endSessionAndStopCasting();
      } catch (_) {}
    }
  }
}
