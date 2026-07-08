import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../native/visualizer_bridge.dart';
import '../util/connectivity_probe.dart';
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

  // Suppresses loss handling during our own teardown. (The renderer-lost
  // emit itself is one-shot at the single emit point in the base class —
  // see EmulatedPlaylistBackend.emitRendererLost / rendererLostEmitted.)
  bool _disposing = false;

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
  // Attempt budgets: an episode that spent time OFFLINE deserves the long
  // budget (Wi-Fi reassociation + SDK re-bind take tens of seconds); one that
  // stayed online throughout (receiver crashed / rebooted) should give up —
  // and fall back to the phone — much sooner.
  static const int _kMaxGraceExtensions = 8; // ≈90s+ worst case
  static const int _kMaxOnlineAttempts = 3; // ≈30-60s when never offline
  bool _episodeWentOffline = false;
  // Bumped per _tryReattach and on dispose: a re-attach that outlives its
  // 30s outer timeout (Future.timeout does NOT cancel the underlying future)
  // or the backend itself must become inert at its next await, not keep
  // starting/ending sessions under the live attempt or after disposal.
  int _reattachGen = 0;
  bool _reattachDiscoveryActive = false;

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
  // A receiver stuck fetching media it can never get (dead iroh tunnel, dead
  // server) keeps its status channel ALIVE — event-silence staleness never
  // trips. Track how long we've been in loading/buffering without reaching
  // playback; past the threshold the track is failed into the bounded walk.
  DateTime? _loadingSince;
  static const Duration _kStuckLoadingAfter = Duration(seconds: 30);
  // Serializes the recovery loop: _onGraceExpired is the ONLY actor (probe /
  // SDK window / re-attach / give up); the watchdog and session events merely
  // ARM its timer. Two concurrent actors double-start sessions and burn the
  // retry budget on attempts made before Play Services can serve them.
  bool _lossBusy = false;
  static const Duration _kStaleAfter = Duration(seconds: 20);

  void _noteRendererEvent() => _lastRendererEvent = DateTime.now();

  // Real POSITION events specifically (status events don't move the bar).
  // Drives both the optimistic extrapolation below and the post-adopt nudge.
  DateTime _lastPositionEventAt = DateTime.now();
  static const Duration _kExtrapolateAfter = Duration(seconds: 2);

  // Optimistic progress while position events are starved: a sender-side
  // blip stops the progress stream but the receiver KEEPS playing, so a
  // frozen bar (then a jump at the next track) is wrong twice. While the
  // last known state is actively playing, advance the position by the tick
  // cadence; real events overwrite it the moment they resume. Clamped to the
  // known duration so it can't run past the track end.
  void _extrapolatePosition() {
    if (!playing || processingState != BackendProcessingState.ready) return;
    if (DateTime.now().difference(_lastPositionEventAt) < _kExtrapolateAfter) {
      return;
    }
    final d = duration;
    final next = position + const Duration(seconds: 1);
    if (d != null && d > Duration.zero && next >= d) return;
    position = next;
    emitPos(position);
    change();
  }

  Future<void> _checkStale() async {
    if (_disposing || rendererLostEmitted) return;
    // Runs even while recovery is live — the receiver is presumed playing
    // through a sender-side loss, and the bar should say so.
    _extrapolatePosition();
    if (_sessionLossGrace != null || _lossBusy) return; // recovery already live
    final loading = _loadingSince;
    if (loading != null &&
        DateTime.now().difference(loading) > _kStuckLoadingAfter) {
      _loadingSince = null;
      appLog('[cast] receiver stuck loading for '
          '${_kStuckLoadingAfter.inSeconds}s — treating as a failed track');
      unawaited(trackFailed('receiver stuck loading', play: playing));
      return;
    }
    if (!playing) return;
    if (DateTime.now().difference(_lastRendererEvent) < _kStaleAfter) return;
    // Offline waits out the LAN like any drop; a half-dead socket with the
    // LAN up skips the SDK-courtesy window (the SDK hasn't even noticed).
    _armLossRecovery(
        offline: !await hasConnectivity(lanOnly: true),
        why: 'no renderer events for ${_kStaleAfter.inSeconds}s while playing');
  }

  /// Single entry point for arming the loss-recovery timer. No-ops when
  /// recovery is already armed/running or moot, so every detector (suspend
  /// event, offline session-end, staleness watchdog) can call it blindly.
  void _armLossRecovery({required bool offline, required String why}) {
    if (_disposing || rendererLostEmitted || _lossBusy) return;
    if (_sessionLossGrace != null) return;
    appLog('[cast] $why — starting loss recovery');
    _graceWasOffline = offline;
    if (offline) _episodeWentOffline = true;
    _sessionLossGrace = Timer(_kSessionLossGrace, _onGraceExpired);
  }

  void _ensureListeners() {
    // 1s cadence: drives the position extrapolation smoothly; the staleness
    // and stuck-loading checks are just DateTime math per tick.
    _staleTicker ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _checkStale());
    _statusSub ??= _client.mediaStatusStream.listen(_onStatus);
    _positionSub ??= _client.playerPositionStream.listen((pos) {
      _noteRendererEvent();
      _lastPositionEventAt = DateTime.now();
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
      // The recovery loop owns the session state during its critical section:
      // its own force-teardown pushes a null that must not be classified as a
      // fresh loss (LAN is up by then — it would fire renderer-lost mid-fix).
      if (_lossBusy) return;
      if (_sessions.hasConnectedSession) {
        // (Re)connected — a suspended session resumed. Cancel any pending
        // loss and reset the episode bookkeeping for the next drop.
        if (_sessionLossGrace != null) {
          appLog('[cast] session resumed within the grace window');
        }
        _sessionLossGrace?.cancel();
        _sessionLossGrace = null;
        _graceExtensions = 0;
        _graceWasOffline = false;
        _episodeWentOffline = false;
        return;
      }
      if (rendererLostEmitted) return;
      if (session == null) {
        // On Android a NETWORK drop surfaces as a full session END (a null
        // push), not a suspend — verified on-device. Probe connectivity
        // before believing it: while offline the "end" is just our own dead
        // network, so it gets the reconnect grace + re-attach like a suspend.
        // A null while online is a genuine end (TV quit) — fall back now.
        unawaited(_onSessionEnded());
        return;
      }
      _armLossRecovery(offline: false, why: 'session suspended');
    });
  }

  Future<void> _onSessionEnded() async {
    final lanUp = await hasConnectivity(lanOnly: true);
    // Recheck EVERYTHING after the async probe: the grace timer or the
    // recovery loop can have started meanwhile, and firing renderer-lost
    // under a running re-attach would tear down the session it is building.
    if (_disposing || rendererLostEmitted || _lossBusy) return;
    if (_sessionLossGrace != null || _sessions.hasConnectedSession) return;
    if (lanUp) {
      _fireRendererLost();
      return;
    }
    _armLossRecovery(offline: true, why: 'session ended while the LAN is down');
  }

  Future<void> _onGraceExpired() async {
    // cancel() too, not just null: the session listener can have armed a FRESH
    // timer in the gap between this one firing and this handler running —
    // dropping that reference without cancelling would leave an orphan timer
    // double-driving this handler.
    _sessionLossGrace?.cancel();
    _sessionLossGrace = null;
    if (_disposing || rendererLostEmitted || _lossBusy) return;
    if (_sessions.hasConnectedSession) return; // SDK recovered on its own
    _lossBusy = true;
    try {
      final budget =
          _episodeWentOffline ? _kMaxGraceExtensions : _kMaxOnlineAttempts;
      if (_graceExtensions >= budget) {
        _fireRendererLost();
        return;
      }
      _graceExtensions++;
      if (!await hasConnectivity(lanOnly: true)) {
        // The LAN is still down — neither the SDK nor we can reach the
        // renderer yet.
        appLog('[cast] loss recovery $_graceExtensions/$_kMaxGraceExtensions: '
            'LAN still down, waiting');
        _graceWasOffline = true;
        _episodeWentOffline = true;
        _rearmLossRecovery();
        return;
      }
      if (_graceWasOffline) {
        // First window after the LAN returned: the SDK auto-resumes a merely
        // SUSPENDED session in this time, and Play Services itself needs a
        // few seconds back on the network before it can start sessions — one
        // quiet window before we intervene.
        appLog('[cast] loss recovery $_graceExtensions/$_kMaxGraceExtensions: '
            'LAN back — giving the SDK one window to resume');
        _graceWasOffline = false;
        _rearmLossRecovery();
        return;
      }
      // The LAN is up and the SDK had its window: re-attach ourselves —
      // rejoin (or relaunch) the receiver and pick playback back up. The
      // receiver keeps playing through a sender-side drop, so a successful
      // rejoin is usually seamless. Retries ride the extension budget. The
      // hard timeout is load-bearing: plugin calls against a broken session
      // can hang FOREVER, and a hanging await never reaches finally — the
      // recovery machine (and everything gated on _lossBusy) would freeze.
      appLog('[cast] loss recovery $_graceExtensions/$_kMaxGraceExtensions: '
          're-attaching');
      final ok = await _tryReattach().timeout(const Duration(seconds: 30),
          onTimeout: () {
        appLog('[cast] re-attach attempt hung (30s) — will retry');
        return false;
      });
      if (ok) {
        appLog('[cast] re-attached to the cast device');
        _graceExtensions = 0;
        _episodeWentOffline = false;
        return;
      }
      if (_sessions.hasConnectedSession) return; // SDK resumed meanwhile
      _rearmLossRecovery();
    } finally {
      _lossBusy = false;
    }
  }

  void _rearmLossRecovery() {
    _sessionLossGrace?.cancel();
    _sessionLossGrace = Timer(_kSessionLossGrace, _onGraceExpired);
  }

  // Rebuild the session after a network-drop END and pick playback back up.
  // If the rejoined receiver reports our media still going (first FRESH
  // status — skip(1) bypasses the stream's stale replayed value), adopt it
  // as-is: the status/position streams resume driving state with no audible
  // hiccup. Otherwise (receiver relaunched idle / nothing arrives) reload the
  // current track at the last known position.
  Future<bool> _tryReattach() async {
    final gen = ++_reattachGen;
    // Inert-after-supersession: the caller's Future.timeout does NOT cancel
    // this future, and dispose can arrive mid-await — a superseded or
    // orphaned attempt must stop acting (no session starts/ends, no reloads)
    // the moment it resumes.
    bool dead() => _disposing || gen != _reattachGen;
    var startedDiscovery = false;
    try {
      // startSessionWithDevice resolves through MediaRouter's LIVE route
      // list — the plugin's native selectRoute silently no-ops (reporting
      // success) when the route is absent — and routes are only maintained
      // while discovery runs, which is normally only while the cast picker
      // is open. Re-populate the routes and wait for OUR device to reappear
      // (post-blip mDNS takes seconds).
      final discovery = GoogleCastDiscoveryManager.instance;
      if (!discovery.devices.any((d) => d.deviceID == _deviceId)) {
        await discovery.startDiscovery();
        startedDiscovery = true;
        _reattachDiscoveryActive = true;
        if (dead()) return false;
        try {
          await discovery.devicesStream
              .firstWhere((ds) => ds.any((d) => d.deviceID == _deviceId))
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          appLog('[cast] re-attach: device not re-discovered yet');
          return false; // device hasn't reappeared — retry next window
        }
        if (dead()) return false;
      }
      _sessionStarted = false; // force _ensureSession to re-connect
      if (_sessions.currentSession != null && !_sessions.hasConnectedSession) {
        // A stale SUSPENDED session lingers, keeping its route selected, and
        // startSessionWithDevice collides with it (every connect wait
        // expires). The graceful endSession() NO-OPs on a suspended session,
        // so force it: the stop command rides the dead socket and never
        // reaches the receiver, which keeps playing — the fresh start below
        // then JOINs it.
        appLog('[cast] re-attach: force-clearing the stale suspended session');
        await _endSessionQuietly(waitForTeardown: true);
        if (dead()) return false;
      }
      await _ensureSession();
      if (dead()) return false;
      if (!_sessions.hasConnectedSession) {
        appLog('[cast] re-attach: session did not connect');
        return false;
      }
      GoggleCastMediaStatus? fresh;
      try {
        fresh = await _client.mediaStatusStream
            .skip(1)
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      if (dead()) return false;
      final alive = fresh?.playerState == CastMediaPlayerState.playing ||
          fresh?.playerState == CastMediaPlayerState.buffering;
      if (alive) {
        // Adopted the still-playing receiver. The SDK's progress listener
        // often stays quiet on a JOINED session until the next load, which
        // froze the bar until the following track. If real position events
        // don't resume shortly, nudge with a same-position seek — the round
        // trip re-establishes the status/progress pipeline, and the target
        // is the extrapolated live position, so the audible skip is ~0.
        final before = _lastPositionEventAt;
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        if (dead()) return true; // adopted; a successor owns any nudging
        if (_lastPositionEventAt == before) {
          appLog('[cast] adopted session is not reporting progress — '
              'nudging with a same-position seek');
          try {
            await _client.seek(GoogleCastMediaSeekOption(position: position));
          } catch (_) {}
        }
      }
      if (!alive) {
        if (_sessions.hasConnectedSession) {
          // The session claims connected but delivers nothing — a half-dead
          // socket the SDK hasn't noticed. Force a genuinely fresh session
          // before reloading, or the loadMedia below goes into the same void.
          await _endSessionQuietly(waitForTeardown: true);
          if (dead()) return false;
          _sessionStarted = false;
          await _ensureSession();
          if (dead()) return false;
          if (!_sessions.hasConnectedSession) return false;
        }
        final ok = await loadIndex(index, play: playing, startAt: position);
        if (!ok) {
          appLog('[cast] re-attach: reload on the rejoined session failed');
          return false;
        }
      }
      return true;
    } catch (e) {
      appLog('[cast] re-attach attempt failed: $e');
      return false;
    } finally {
      // Don't leave a background mDNS scan running (battery); the picker
      // manages its own discovery lifecycle when open. A superseded attempt
      // leaves the scan to its successor; dispose stops any leftover scan.
      if (startedDiscovery && (gen == _reattachGen || _disposing)) {
        _reattachDiscoveryActive = false;
        try {
          await GoogleCastDiscoveryManager.instance.stopDiscovery();
        } catch (_) {}
      }
    }
  }

  /// Force-end the current Cast session, swallowing failures. With
  /// [waitForTeardown], also wait (bounded) for the session stream to settle
  /// on null — starting a new session against a half-torn-down one collides
  /// and times out its connect wait.
  Future<void> _endSessionQuietly({bool waitForTeardown = false}) async {
    try {
      await _sessions.endSessionAndStopCasting();
    } catch (_) {}
    if (!waitForTeardown) return;
    try {
      await _sessions.currentSessionStream
          .firstWhere((s) => s == null)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void _fireRendererLost() {
    _sessionLossGrace?.cancel();
    _sessionLossGrace = null;
    appLog(_graceExtensions == 0
        ? '[cast] session ended while online — falling back to this phone'
        : '[cast] session lost after $_graceExtensions recovery attempts — '
            'falling back to this phone');
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
        _loadingSince = null;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.paused:
        playing = false;
        _loadingSince = null;
        setProcessingState(BackendProcessingState.ready);
        break;
      case CastMediaPlayerState.buffering:
        _loadingSince ??= DateTime.now();
        setProcessingState(BackendProcessingState.buffering);
        break;
      case CastMediaPlayerState.loading:
        _loadingSince ??= DateTime.now();
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
          final wasPlaying = playing;
          playing = false;
          trackFailed('receiver reported a media error', play: wasPlaying);
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
      await _endSessionQuietly();
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

  GoogleCastMediaInformation _mediaInfo(MediaItem item, String url) {
    // Full-res art (drop the compress= size param) — looks sharp on a TV; for an
    // iroh server it's relayed through the LAN proxy (LocalMediaServer already
    // started by resolveRendererUri) so the receiver can fetch it.
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
    // events for many seconds — restart the staleness and stuck-loading clocks.
    _noteRendererEvent();
    _lastPositionEventAt = DateTime.now();
    _loadingSince = DateTime.now();
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
          final url = (await resolveRendererUri(items[target])).toString();
          if (gen != _loadGen) return true;
          await _client.loadMedia(_mediaInfo(items[target], url),
              autoPlay: play, playPosition: startAt);
        }
      } else {
        final url = (await resolveRendererUri(items[target])).toString();
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
      final ok = await loadIndex(index, play: true);
      if (!ok) unawaited(trackFailed('load failed', play: true));
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
      final intent = play ?? playing;
      final ok = await loadIndex(target, play: intent, startAt: position);
      // A failed user-driven load has no watchdog before the first successful
      // _ensureSession (the ticker arms in _ensureListeners) — walk instead
      // of stranding the backend in 'loading'.
      if (!ok) unawaited(trackFailed('load failed', play: intent));
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
    if (n != null) {
      final intent = playing;
      final ok = await loadIndex(n, play: intent);
      if (!ok) unawaited(trackFailed('load failed', play: intent));
    }
  }

  @override
  Future<void> seekToPrevious() async {
    if (index > 0) {
      final intent = playing;
      final ok = await loadIndex(index - 1, play: intent);
      if (!ok) unawaited(trackFailed('load failed', play: intent));
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
    _reattachGen++; // any in-flight re-attach becomes inert at its next await
    _sessionLossGrace?.cancel();
    _staleTicker?.cancel();
    if (_reattachDiscoveryActive) {
      _reattachDiscoveryActive = false;
      try {
        await GoogleCastDiscoveryManager.instance.stopDiscovery();
      } catch (_) {}
    }
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
      await _endSessionQuietly();
    }
  }
}
