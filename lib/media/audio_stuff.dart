import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart'
    show AudioSession, AudioSessionConfiguration;
import 'package:just_audio/just_audio.dart';
import 'package:mstream_music/main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_lock_shim/wifi_lock_shim.dart';
import 'playback_backend.dart';
import 'local_playback_backend.dart';
import 'dlna_playback_backend.dart';
import 'chromecast_playback_backend.dart';
import 'local_media_server.dart';
import 'auto_browse.dart';
import 'cast_log.dart';
import 'cast_target.dart';
import '../native/iroh_tunnel.dart';
import '../objects/server.dart';
import '../objects/metadata.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/cast_manager.dart';
import '../singletons/app_messenger.dart';
import '../singletons/downloads.dart';
import '../singletons/log_manager.dart';
import '../singletons/queue_store.dart';
import '../singletons/settings.dart';
import '../singletons/server_list.dart';
import '../singletons/visualizer_audio.dart';
import '../util/camelot.dart';
import '../util/connectivity_probe.dart';
import '../util/stream_url.dart';

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  // Playback is delegated to a swappable backend so casting can move audio
  // off-device without changing the queue / Auto-DJ / shuffle / repeat logic
  // here. The active backend lives in a BehaviorSubject; the handler's derived
  // streams switchMap over it so existing listeners auto-resubscribe when the
  // backend swaps (see positionStream and _init). The local just_audio backend
  // is persistent (reused when switching back from a cast device); remote
  // backends are built per-session and disposed on switch-away.
  // Build the EQ pipeline only if the user has it enabled — a plain player is
  // the default (see LocalPlaybackBackend). SettingsManager().load() runs
  // before this handler is constructed (main.dart), so eqEnabled is populated.
  late final LocalPlaybackBackend _localBackend =
      LocalPlaybackBackend(withEqualizer: SettingsManager().eqEnabled);
  late final BehaviorSubject<PlaybackBackend> _backendSubject =
      BehaviorSubject<PlaybackBackend>.seeded(_localBackend);
  PlaybackBackend get _backend => _backendSubject.value;

  // Serializes cast-target switches so rapid re-selection can't interleave two
  // _switchBackend calls (racing on _backend / dispose).
  Future<void> _switchChain = Future<void>.value();

  // Completes when _init() has finished seeding the backend + applying saved EQ.
  // restoreQueue() (fired in parallel from QueueStore.init once the server list
  // loads) awaits this so its setSources() can't race _init's seed/EQ on the
  // single just_audio player — concurrent loads abort each other with
  // "Loading interrupted".
  final Completer<void> _initialized = Completer<void>();

  // Android-only native equalizer, exposed for the EQ screen. Lives on the
  // local backend (null on non-Android / remote backends). eq_screen.dart
  // reads this via MediaManager().audioHandler.equalizer.
  AndroidEqualizer? get equalizer => _backend.equalizer;

  int? get index => _backend.currentIndex;

  /// Live playback position of the active backend (read by QueueStore so the
  /// saved snapshot carries the exact spot in the current track).
  Duration get position => _backend.position;

  Stream<Duration> get positionStream =>
      _backendSubject.switchMap((b) => b.positionStream);

  // Android audio session id of the active backend. The visualizer's
  // real-audio capture attaches a Visualizer to THIS session — the
  // global output mix (session 0) is blocked for normal apps on modern
  // Android. Null until a source has loaded (or while casting).
  int? get androidAudioSessionId => _backend.androidAudioSessionId;

  Server? autoDJServer;

  dynamic jsonAutoDJIgnoreList;

  // One toast per session for an Auto-DJ auth failure (401/403) — every
  // queue-end retriggers autoDJ, and each would re-toast otherwise.
  bool _autoDJAuthWarned = false;

  // Session-only: rolling sonic anchor — the last few DJ-picked filepaths,
  // sent as random-songs' `similarTo` seeds so the server centroids the
  // session's own recent sound (webapp auto-dj.js parity). Reset alongside
  // the ignoreList on setAutoDJ off / server switch.
  List<String> _sonicHistory = const [];
  // One toast per session for a sonic fail-loud (pool empty / seed not
  // analyzed) — same retrigger-spam collapse as [_autoDJAuthWarned].
  bool _sonicWarned = false;

  // Session-only: the Camelot anchor for harmonic mixing. Locked on
  // the first DJ-picked song with a recognised key (after that, every
  // subsequent pick uses the anchor's 6 Camelot neighbours, keeping
  // the session musically coherent rather than drifting). Reset on
  // setAutoDJ off or server switch.
  String? _camelotAnchor;

  // The repeat mode requested by the UI / Android Auto, and the source of truth
  // for the published PlaybackState: it preserves all of none/all/one (and
  // 'group', which the backend collapses to 'all'), so a client that cycles
  // none→all→one→none can always get back to none. The backend honours the
  // mapped BackendRepeat — including a true single-track loop for 'one'.
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  AudioPlayerHandler() {
    // Complete _initialized when _init() finishes (success or failure) so a
    // parallel restoreQueue() never issues setSources() while _init's seed/EQ
    // are still loading. whenComplete guarantees it even if _init throws, so
    // restoreQueue can't hang.
    _init().whenComplete(() {
      if (!_initialized.isCompleted) _initialized.complete();
    });
  }

  Future<void> _init() async {
    // Configure the platform audio session for music playback. Without this,
    // focus is requested with default attributes and Android is more likely to
    // classify a transient loss (a call, a nav prompt, a notification ding) as
    // a permanent one — which pauses playback and never auto-resumes. Declaring
    // music attributes makes focus/duck/resume behave deterministically.
    //
    // We deliberately do NOT add becomingNoisy / interruption *handlers* here:
    // just_audio already wires those up internally (handleInterruptions
    // defaults to true) and auto-pauses/resumes. A second handler would
    // double-fire and fight it. The listener below is logging-only (read-only),
    // so a "stopped after a call and never came back" report is diagnosable.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) {
        appLog('[audio] interruption '
            '${event.begin ? 'begin' : 'end'} type=${event.type}');
      });
    } catch (e) {
      appLog('[audio] audio session configure failed: $e');
    }

    // For Android 11, record the most recent item so it can be resumed.
    mediaItem
        .whereType<MediaItem>()
        .listen((item) => _recentSubject.add([item]));
    // Broadcast media item changes (with duration if it's known yet).
    // These derived streams switchMap over the active backend so they keep
    // working across a cast backend swap — the new backend's streams are
    // subscribed automatically and the old ones cancelled.
    _backendSubject.switchMap((b) => b.currentIndexStream).listen((index) {
      // A reorder re-points the backend's currentIndex without playback
      // advancing, so skip the Auto-DJ top-up (and the now-playing re-emit) —
      // otherwise dragging the playing track to the last slot would append a
      // spurious Auto-DJ track.
      if (_reordering || _rebuilding) return;
      if (index == queue.value.length - 1) {
        autoDJ();
      }
      if (index != null && index >= 0 && index < queue.value.length) {
        final item = queue.value[index];
        if (item.id != _lastPlayLoggedId) {
          _lastPlayLoggedId = item.id;
          appLog('[play] track ${index + 1}/${queue.value.length}: '
              '${item.title}');
        }
      }
      _emitCurrentMediaItem();
    });
    // Tunnel-follows-queue (one-iroh-server cap): keep the iroh tunnel up whenever
    // the queue holds a song from the iroh server, and let it go when none remain.
    // Recomputed on every queue edit; with the cap, the first iroh match is THE
    // iroh server. This is what makes a queue from the iroh server connect in the
    // background while the default stays selected.
    queue.listen((items) {
      Server? iroh;
      for (final it in items) {
        final s = _serverFor(it);
        if (s != null && s.isIroh) {
          iroh = s;
          break;
        }
      }
      ServerManager().setQueueIrohServer(iroh);
      // Keep-queue-offline: sweep every queue change for tracks to download.
      // No-op unless the setting is on; DownloadManager dedupes (in-flight,
      // once-per-session, already-on-disk). Lives here — not main.dart — so
      // headless sessions (Android Auto + Auto-DJ top-ups) sweep too.
      unawaited(DownloadManager().autoDownloadQueue(items));
    });
    // duration usually arrives via durationStream after the source
    // loads. Re-emit the current MediaItem with the duration filled in
    // so the BottomBar progress formula stops dividing by 1.
    _backendSubject
        .switchMap((b) => b.durationStream)
        .listen((_) => _emitCurrentMediaItem());
    // Propagate backend state changes to AudioService clients.
    _backendSubject
        .switchMap((b) => b.changeStream)
        .listen((_) => _broadcastState());
    // On-device playback errors arrive on the backend's dedicated errorStream
    // (just_audio's error channel), NOT as errors on changeStream — recover the
    // iroh mid-stream-drop case from here.
    _backendSubject.switchMap((b) => b.errorStream).listen(_onPlaybackError);
    // The iroh supervisor re-dials a dropped tunnel forever on the same
    // loopback port, so a dead server coming back flips this status to
    // connected without any app-side event: the phone's network never changed
    // (the connectivity listener stays silent) and the error-time recovery
    // timed out long ago. This transition is the only signal that playback
    // parked by the outage can resume.
    ServerManager().tunnelStatusStream.listen((status) {
      final prev = _lastTunnelStatus;
      _lastTunnelStatus = status;
      if (prev == null || prev == IrohTunnelStatus.connected) return;
      if (status == IrohTunnelStatus.connected) _onTunnelReconnected();
    });
    // Stop the service when playback reaches the end of the queue.
    _backendSubject.switchMap((b) => b.processingStateStream).listen((state) {
      if (state == BackendProcessingState.completed) {
        // Log the context so a "stopped on its own" report can be told apart
        // from a genuine end-of-queue stop: how far into the track we were vs.
        // its duration, and where we were in the queue.
        appLog('[play] completed → stop '
            'pos=${_backend.position.inSeconds}s/'
            '${_backend.duration?.inSeconds ?? '?'}s '
            'index=${_backend.currentIndex} of ${queue.value.length}');
        stop();
      }
      // A track that loads clears the skip-budget AND the HTTP retry budget,
      // and lifts any network-stall pause — so the guards only trip on a genuine
      // run of failures, not after a recovery.
      if (state == BackendProcessingState.ready) {
        _failedSkips = 0;
        _httpRetries = 0;
        _networkStalled = false;
        // A track actually loaded — the live player state is the truth now;
        // stop overriding reads with the failed-restore park.
        _restoreSpot = null;
        // Saved EQ gains can only be pushed once a source has loaded (the
        // equalizer's parameters resolve on activation), so apply them here
        // on the first ready after init/restore or an EQ-toggle rebuild.
        if (_eqGainsPending && equalizer != null) unawaited(_pushSavedGains());
      }
      // Any fresh load re-resolves its source from the current extras
      // (_uriFor), so the loaded-source-predates-download-patch marker is
      // done (see onTrackDownloaded / _updateWifiLock).
      if (state == BackendProcessingState.loading) {
        _currentSourcePredatesPatch = false;
      }
    });
    // A remote backend that loses its renderer mid-cast (TV off, Wi-Fi drop)
    // emits here; fall back to local playback at the same spot + a toast.
    _backendSubject
        .switchMap((b) => b.rendererLostStream)
        .listen(_onRendererLost);
    // Route cast-target selection (from the picker) to a backend swap.
    CastManager().onTargetSelected = _switchToTarget;
    try {
      // Seed the backend with whatever is already in the queue
      // (typically empty on cold start).
      await _backend.setSources(queue.value);
    } catch (e) {
      castLog('Error seeding playback backend', error: e);
    }
    await _applySavedEqualizer();
  }

  // Apply persisted EQ state. setEnabled is immediate; band gains can only be
  // pushed once a source has loaded (the equalizer's parameters resolve on
  // activation), so we just arm _eqGainsPending here and the processingState
  // 'ready' handler pushes them on first load. This never blocks _init or the
  // _switchChain toggle on an idle player (where parameters never resolves).
  Future<void> _applySavedEqualizer([AndroidEqualizer? target]) async {
    final eq = target ?? equalizer;
    if (eq == null) return;
    try {
      await eq.setEnabled(SettingsManager().eqEnabled);
    } catch (e) {
      appLog('[eq] enable error: $e');
    }
    _eqGainsPending =
        SettingsManager().eqEnabled && SettingsManager().eqBandGains.isNotEmpty;
  }

  // Push saved band gains onto the active equalizer once a source has loaded
  // (driven by the 'ready' handler, where parameters resolves immediately —
  // the timeout is only a safety net). Leaves _eqGainsPending set if it can't
  // apply yet (no equalizer / not loaded), so a later ready retries.
  bool _eqGainsPending = false;
  Future<void> _pushSavedGains() async {
    final eq = equalizer;
    if (eq == null) return;
    final saved = SettingsManager().eqBandGains;
    if (saved.isEmpty) {
      _eqGainsPending = false;
      return;
    }
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      for (var i = 0; i < params.bands.length && i < saved.length; i++) {
        await params.bands[i].setGain(saved[i]);
      }
      _eqGainsPending = false;
    } catch (e) {
      appLog('[eq] gain apply error: $e');
    }
  }

  /// Toggle the native EQ on or off. just_audio fixes the audio pipeline at
  /// player construction, so this rebuilds the local player WITH or WITHOUT
  /// the EQ effect (LocalPlaybackBackend.rebuildPlayer) and carries playback
  /// across at the same spot. Serialized through _switchChain so it can't
  /// interleave with a cast switch, error recovery, or the launch restore.
  /// Called by the EQ screen.
  Future<void> setEqEnabled(bool enabled) {
    _switchChain = _switchChain
        .then((_) => _doSetEqEnabled(enabled))
        .catchError((Object e) => appLog('[eq] toggle failed: $e'));
    return _switchChain;
  }

  Future<void> _doSetEqEnabled(bool enabled) async {
    // Don't race _init's seed/EQ on the single player (the same gate
    // restoreQueue waits on). Runs serialized on _switchChain — see above.
    await _initialized.future;

    // Casting: the local backend is inactive. Rebuild it so it's correct when
    // the user returns to the phone, but leave the active (cast) backend
    // untouched. No re-seed here — _switchBackend re-seeds the local backend
    // with fresh URLs on every return-to-local anyway, and loading sources
    // now would just bake soon-stale tunnel ports into a parked player.
    if (!identical(_backend, _localBackend)) {
      await _localBackend.rebuildPlayer(withEqualizer: enabled);
      await SettingsManager().setEqEnabled(enabled);
      if (enabled) await _applySavedEqualizer(_localBackend.equalizer);
      return;
    }

    // Local backend active — carry position / index / play + shuffle/repeat
    // across the rebuild (the new player starts empty). _reviveSpot: a parked
    // failed-restore spot must survive the rebuild, not be replaced by the
    // never-loaded player's index 0.
    final spot = _reviveSpot();
    final wasShuffle = _localBackend.shuffleEnabled;
    final wasRepeat = _localBackend.repeat;

    // _rebuilding suppresses the currentIndexStream Auto-DJ top-up, the
    // now-playing re-emit, and state broadcasts while the swap is mid-flight:
    // the old player's dispose-time events would otherwise be read through
    // the NEW empty player and publish a transient bogus `error` state (queue
    // non-empty + idle + no intentional stop) to the media session.
    _rebuilding = true;
    try {
      await _localBackend.pause();
      await _localBackend.rebuildPlayer(withEqualizer: enabled);
      // Re-emit IMMEDIATELY (same instance): the switchMap-derived streams
      // must rebind to the NEW player before its first load — a failed
      // re-seed below would otherwise leave the handler deaf forever on the
      // disposed player's closed streams, and the re-seed's 'loading' event
      // (which clears the WifiLock predates-patch marker) would go
      // unobserved. Player streams replay current state on subscribe, so the
      // early rebind loses nothing.
      _backendSubject.add(_localBackend);
      // Persist only after the rebuild succeeds, so a thrown rebuild can't
      // leave the setting saying "on" with no pipeline attached.
      await SettingsManager().setEqEnabled(enabled);
      // Enable EQ + arm the saved-gains apply BEFORE the re-seed, so the
      // gains are already pending when the new source's first 'ready' fires.
      if (enabled) await _applySavedEqualizer();
      await _localBackend.setShuffleEnabled(wasShuffle);
      await _localBackend.setRepeat(wasRepeat);
      try {
        final fresh = _queueWithFreshUrls();
        if (fresh.isNotEmpty) {
          await _localBackend.setSources(fresh);
          // Live _playIntent, not a captured wasPlaying: a pause (or play)
          // landing during the network-bound load must win — the same
          // post-await doctrine as every revive path.
          await _localBackend.seek(spot.position,
              index: spot.index.clamp(0, fresh.length - 1),
              play: _playIntent);
        }
      } catch (e) {
        // Same park as a failed launch restore: the new player is empty, so
        // without this the next revive / snapshot save would land on
        // track 1 / 0:00 instead of the user's spot.
        _restoreSpot = (index: spot.index, position: spot.position);
        appLog('[eq] re-seed after EQ toggle failed — spot parked: $e');
      }
      // The rebuilt player has a new audio-session id — re-point the
      // visualizer's real-audio capture (no-op unless actively tapping).
      unawaited(VisualizerAudio().reattachSession());
    } finally {
      _rebuilding = false;
    }
    _broadcastState();
    _emitCurrentMediaItem();
  }

  void _emitCurrentMediaItem() {
    if (_reordering || _rebuilding) return;
    if (queue.value.isEmpty) return;
    // A failed launch restore parks a spot the backend never reached — show
    // THAT track as now-playing, not track 1. Spot FIRST: the failed load
    // leaves the backend's currentIndex at 0 (not null), so an index-first
    // read never falls through. Cleared on ready / user navigation.
    final i = (_restoreSpot?.index ?? index ?? 0)
        .clamp(0, queue.value.length - 1);
    final item = queue.value[i];
    final dur = _backend.duration;
    mediaItem.add(dur != null ? item.copyWith(duration: dur) : item);
  }

  /// Switch playback to a [CastTarget] chosen in the cast picker. Builds the
  /// matching backend (the persistent local just_audio backend, or a fresh
  /// DLNA session) and hands it the current queue + position so playback
  /// continues on the new device. Wired to CastManager.onTargetSelected.
  Future<void> _switchToTarget(CastTarget target, bool visualizer) {
    _switchChain = _switchChain
        .then((_) => _doSwitchToTarget(target, visualizer))
        .catchError((Object e) {
      castLog('Cast backend switch failed', error: e);
    });
    return _switchChain;
  }

  Future<void> _doSwitchToTarget(CastTarget target, bool visualizer) async {
    final PlaybackBackend next;
    if (target.isLocal) {
      next = _localBackend;
    } else if (target.kind == CastTargetKind.dlna) {
      next = DlnaPlaybackBackend(udn: target.id);
    } else if (target.kind == CastTargetKind.chromecast) {
      // visualizer = stream the on-device visualizer (video) instead of audio.
      next = ChromecastPlaybackBackend(
          deviceId: target.id, visualizer: visualizer);
    } else {
      return;
    }
    if (identical(next, _backend)) return;
    // A visualizer cast makes the phone the renderer's byte origin (on-device
    // HLS transcode served by LocalMediaServer) — the WifiLock heuristics need
    // to know, and the backend itself doesn't expose it.
    _castVisualizer = !target.isLocal && visualizer;
    await _switchBackend(next);
  }

  // Carry the current position / index / playing state + shuffle/repeat to the
  // new backend, make it active (switchMap re-subscribes the derived streams),
  // resume, then tear down the previous backend if it was a per-session remote
  // one (the local backend is persistent and reused).
  Future<void> _switchBackend(PlaybackBackend next) async {
    final prev = _backend;
    final pos = prev.position;
    final idx = prev.currentIndex ?? 0;
    final wasPlaying = prev.playing;
    // The switch carries the AUDIBLE state, so the intent must follow it:
    // playback started from a renderer's own remote never went through
    // handler.play(), and a stale intent=false would make every intent-gated
    // resume (skip-after-error, recoveries) land paused mid-listen after
    // returning to the phone.
    _playIntent = wasPlaying;

    await prev.pause();

    await next.setShuffleEnabled(prev.shuffleEnabled);
    await next.setRepeat(prev.repeat);
    // Returning to the phone must re-derive queue URLs (the auto rebuild is
    // skipped while casting; a tunnel restart mid-cast leaves stale loopback
    // ports in the stored ids). Cast backends re-resolve per track instead.
    await next.setSources(identical(next, _localBackend)
        ? _queueWithFreshUrls()
        : queue.value);
    _backendSubject.add(next);
    if (queue.value.isNotEmpty) {
      // Carry the play state into the load: a renderer then auto-plays when its
      // media is ready (no load-paused-then-race-play), and we don't await the
      // local backend's play() — whose future only completes on pause/stop, so
      // awaiting it here used to block the switch and leave the cast session
      // connected until the user hit pause.
      await next.seek(pos, index: idx, play: wasPlaying);
    }
    _broadcastState();

    // The remote backends swallow load/connection errors internally (so they
    // never throw here); detect a failed cast by whether playback actually
    // starts. If the renderer is unreachable / a Cast session won't connect /
    // the media is unplayable, fall back to local so playback isn't left
    // silently dead, and surface a toast.
    final isRemote = !identical(next, _localBackend);
    if (isRemote && wasPlaying && queue.value.isNotEmpty) {
      final started = await _awaitRemoteStart(next);
      if (!started) {
        await _fallBackToLocal(prev, next, pos, idx);
        return;
      }
    }

    if (!identical(prev, _localBackend)) {
      // Chromecast → Chromecast (device change or visualizer toggle): the Cast
      // session is app-global, shared by both backend instances — the outgoing
      // one must not end the session the new one just loaded media on.
      if (prev is ChromecastPlaybackBackend &&
          next is ChromecastPlaybackBackend) {
        prev.prepareCastToCastHandoff(next);
      }
      await prev.dispose();
    }
    // Switched back to the phone — tear down the local file server (no-op if it
    // was never started). A remote→remote switch keeps it up for the new one.
    if (identical(next, _localBackend)) {
      await LocalMediaServer().stop();
    }
  }

  // True once a freshly-activated remote backend actually starts (reaches
  // ready/playing) within a timeout; false if it stays stuck loading (renderer
  // unreachable / session won't connect / unplayable media).
  Future<bool> _awaitRemoteStart(PlaybackBackend backend) async {
    bool started(BackendProcessingState s) =>
        s == BackendProcessingState.ready ||
        s == BackendProcessingState.completed;
    if (started(backend.processingState)) return true;
    try {
      await backend.processingStateStream
          .firstWhere(started)
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      appLog('[cast] remote start timed out (12s)');
      return false;
    }
  }

  // A cast failed to start — resume on the phone at the same spot, tear down
  // the failed (and abandoned previous) remote backend, and tell CastManager
  // so the UI reverts to "This device" and shows a message.
  Future<void> _fallBackToLocal(PlaybackBackend prev, PlaybackBackend failed,
      Duration pos, int idx) async {
    appLog('[cast] cast failed to start — back to this phone '
        'at track ${idx + 1}, ${pos.inSeconds}s');
    try {
      await failed.pause();
    } catch (_) {}
    await _reseedLocalAfterCastLoss(
      pos: pos,
      idx: idx,
      play: true,
      dispose: [
        if (!identical(failed, _localBackend)) failed,
        if (!identical(prev, _localBackend) && !identical(prev, failed)) prev,
      ],
      message: "Couldn't play on the cast device — back on this phone",
    );
  }

  // A remote renderer dropped offline *during* playback (not at switch time —
  // that's _fallBackToLocal). Resume on the phone at the current spot and tell
  // CastManager (reverts the UI to "This device" + toast). Serialized through
  // _switchChain so it can't interleave with a user-initiated target switch.
  void _onRendererLost(String message) {
    _switchChain = _switchChain.then((_) async {
      final failed = _backend;
      if (identical(failed, _localBackend)) return; // already recovered
      final pos = failed.position;
      final idx = failed.currentIndex ?? 0;
      final wasPlaying = failed.playing;
      appLog('[cast] renderer lost mid-cast — back to this phone at '
          'track ${idx + 1}, ${pos.inSeconds}s (playing=$wasPlaying)');
      await _reseedLocalAfterCastLoss(
          pos: pos, idx: idx, play: wasPlaying, dispose: [failed], message: message);
    }).catchError((Object e) {
      castLog('Renderer-lost fallback failed', error: e);
    });
  }

  /// Shared tail of every lost/failed-cast fallback: reseed the LOCAL backend
  /// with the queue (URLs refreshed — see [_queueWithFreshUrls]) and park/play
  /// at [pos]/[idx], then — in a `finally`, so a reseed fighting a dead server
  /// can't skip it — hand the subject over, dispose the remote [dispose]
  /// backends (leaking one leaves its tickers + session listeners running),
  /// stop the LAN file server, and surface [message]. The subject swap sits in
  /// the `finally` too: after a THROWING reseed the handler must still point
  /// at the local backend (whose errorStream recovery owns dead-server
  /// handling), and on the happy path swapping after the load means the
  /// switchMap listeners replay a loaded player, not a stale idle one.
  Future<void> _reseedLocalAfterCastLoss({
    required Duration pos,
    required int idx,
    required bool play,
    required List<PlaybackBackend> dispose,
    required String message,
  }) async {
    try {
      final items = _queueWithFreshUrls();
      await _localBackend.setSources(items);
      if (items.isNotEmpty) {
        await _localBackend.seek(pos, index: idx, play: play);
      }
    } finally {
      _backendSubject.add(_localBackend);
      _broadcastState();
      for (final b in dispose) {
        await b.dispose();
      }
      await LocalMediaServer().stop();
      CastManager().reportCastFailed(message);
    }
  }

  /// The queue with every stream URL re-derived against the CURRENT tunnel /
  /// transcode state, updating the queue subject when anything changed. The
  /// auto rebuild is skipped while casting (cast loads re-resolve per track),
  /// so this is the deferred catch-up every return-to-local must run: after a
  /// tunnel restart mid-cast the stored ids still carry the OLD loopback
  /// port/token, and seeding just_audio with those fails on a tunnel that
  /// LOOKS healthy (tunnelServes == true), which sidesteps the iroh recovery.
  List<MediaItem> _queueWithFreshUrls() {
    final q = queue.value;
    if (q.isEmpty) return q;
    final rebuilt = q.map(_withRebuiltUrl).toList();
    var changed = false;
    for (int i = 0; i < q.length; i++) {
      if (!identical(rebuilt[i], q[i])) changed = true;
    }
    if (!changed) return q;
    appLog('[queue] stream URLs refreshed on return to local playback');
    queue.add(rebuilt);
    return rebuilt;
  }

  // just_audio surfaced a playback error (local stream path only — remote
  // backends report failures via rendererLostStream). The split, keyed on the
  // FAILED track's iroh server (the tunnel "follows playback", so it may not be
  // the browsed server):
  //  • iroh source whose tunnel is NOT live for it yet — launch, a cross-server
  //    queue advance that needs a tunnel switch, or a mid-stream drop → recover in
  //    place (ensure that server's tunnel, then re-seed + resume), don't skip;
  //  • anything else (local/HTTP source, or an iroh source whose tunnel IS up and
  //    it still failed = bad source) → warn and skip to the next track.
  void _onPlaybackError(Object error) {
    if (!identical(_backend, _localBackend)) return;
    // Diagnostic: capture the error class + where we were, so a network-blip
    // stop can be distinguished from a genuinely-unplayable source in the logs.
    appLog('[play] playback error ($error) '
        'index=${_localBackend.currentIndex} '
        'failedSkips=$_failedSkips/${queue.value.length}');
    // One error-handler at a time: while a recover or skip is in flight, ignore
    // further errors (a burst for one failure, or the wrap-around after a skip).
    // Whatever's playing when it finishes re-decides on its own fresh error.
    if (_recoveringPlayback || _skipPending) return;
    final idx = _localBackend.currentIndex;
    final q = queue.value;
    final failed = (idx != null && idx >= 0 && idx < q.length) ? q[idx] : null;
    final itemServer = failed == null ? null : _serverFor(failed);
    if (itemServer != null &&
        itemServer.isIroh &&
        !ServerManager().tunnelServes(itemServer)) {
      // The tunnel isn't live for this track's iroh server — point it there and
      // resume rather than skipping. (If it IS serving this server and the track
      // still failed, that's a bad source → falls through to skip below.)
      _recoverIrohPlayback(itemServer);
      return;
    }
    // Non-iroh source failed → hand off to _recoverHttpError, which (with an
    // async connectivity probe) pauses-and-holds on a real outage, retries a
    // transient blip in place, or skips a genuinely bad source.
    _recoverHttpError(error);
  }

  // Resume after an iroh playback error whose tunnel isn't live yet: a mid-stream
  // drop (the supervisor reconnects the same loopback port) or a launch where the
  // tunnel wasn't up when the queue was restored. The tunnel target is owned by
  // the queue listener (this server's songs are queued); just await it for
  // [server], then re-seed (URLs rebuilt on the (re)bind) + resume with the user's
  // play intent. Per-server debounced + guarded so a failing source can't spin.
  bool _recoveringPlayback = false;
  // Per-server cooldown (keyed by localname) so a persistently-failing server
  // can't spin on recovery.
  final Map<String, DateTime> _lastRecoveryByServer = {};
  void _recoverIrohPlayback(Server server) {
    if (_recoveringPlayback) return;
    final now = DateTime.now();
    final last = _lastRecoveryByServer[server.localname];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    // A transport drop isn't a bad source — don't let it eat the skip budget.
    _failedSkips = 0;
    _recoveringPlayback = true;
    _lastRecoveryByServer[server.localname] = now;
    // The tunnel target is owned by the queue listener (this server's songs are
    // queued, so it's already the target); just wait for it and re-seed.
    _switchChain = _switchChain.then((_) async {
      if (queue.value.isEmpty) return;
      // _reviveSpot: a launch-restore whose load failed parks at the SAVED
      // spot — the never-loaded backend would report track 1 / 0:00.
      final spot = _reviveSpot();
      final pos = spot.position;
      final idx = spot.index;
      final ready = await ServerManager().awaitTunnelReady(server: server);
      if (!ready) return; // tunnel didn't come up; the banner shows why
      // Rebuild URLs against the now-live tunnel ourselves rather than reusing
      // queue.value: a hard restart may have changed the port/token, and the
      // concurrent rebuild-on-(re)bind might not have refreshed queue.value yet —
      // _withRebuiltUrl uses the current effectiveBaseUrl, so these are always live.
      final fresh = queue.value.map(_withRebuiltUrl).toList();
      queue.add(fresh);
      await _localBackend.setSources(fresh);
      // Resume with the user's intent: a mid-stream drop while playing resumes
      // playing; a launch-time recovery (never played) stays paused.
      await _localBackend.seek(pos, index: idx, play: _playIntent);
    }).catchError((Object e) {
      castLog('iroh playback recovery failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  // Consecutive failed tracks since one last loaded (reset on a `ready` state).
  int _failedSkips = 0;
  // True while a skip is chained/running — collapses an error burst into one skip
  // and keeps the before/after index read uncontended.
  bool _skipPending = false;
  DateTime? _lastErrorToast;
  // Collapse a run of failures into one toast (a long unplayable stretch
  // shouldn't fire a snackbar per track).
  static const Duration _kErrorToastGap = Duration(seconds: 4);

  // ── HTTP transient-error retry (resume-at-position) ──
  // A plain-HTTP source that drops mid-stream (a network blip, screen-off Wi-Fi
  // park, cellular handoff) used to skip immediately — and a queue-wide blip
  // stopped everything. Instead we retry the SAME track at the same spot a few
  // times with backoff before giving up. The counter resets to 0 when any track
  // actually loads (`ready`), so it bounds total retry effort during a real
  // outage: the first failing track retries, the rest skip fast.
  static const int _kMaxHttpRetries = 3;
  int _httpRetries = 0;
  // Set when a queue-wide network failure has PAUSED (not stopped) playback, so
  // a later connectivity-regained event (onNetworkRegained) resumes it. Cleared
  // when a track loads again.
  bool _networkStalled = false;

  // A source failed to play — warn (debounced) and skip to the next track, bounded
  // so an entirely-unplayable queue stops instead of looping (notably under
  // repeat-all). Serialized via _switchChain by the caller; local backend only.
  Future<void> _skipFailedTrack(Object error) async {
    if (!identical(_backend, _localBackend)) return; // switched to a renderer meanwhile
    final q = queue.value;
    if (q.isEmpty) return;
    castLog('playback error — skipping track', error: error);
    _failedSkips++;
    if (_failedSkips >= q.length) {
      // Tried every track once and none loaded. The error string can't tell a
      // 404 from a network drop on Android (ExoPlayer reports both as a generic
      // "Source error"), so probe the actual network: no connectivity → a real
      // outage, PAUSE (don't stop) and arm onNetworkRegained to resume when it
      // returns; connectivity present → the sources/server are bad, so stop.
      _failedSkips = 0;
      if (!await hasConnectivity()) {
        _showPlaybackErrorToast(
            'Lost the connection — paused. Resumes when you’re back online.');
        await _localBackend.pause();
        _networkStalled = true;
      } else {
        _showPlaybackErrorToast(
            "Can't play these tracks — check the files or server.");
        _intentionalStop = true;
        await _localBackend.stop();
      }
      _broadcastState();
      return;
    }
    _showPlaybackErrorToast('Skipping a track that won’t play.', debounce: true);
    final before = _localBackend.currentIndex;
    // seekToNext()'s Future completes only after _player.currentIndex is updated,
    // so the post-await read reliably reflects the new position.
    await _localBackend.seekToNext(); // shuffle/repeat-aware
    if (_localBackend.currentIndex == before) {
      // No-op → end of the queue with no repeat. Probe the network (the error
      // string can't distinguish outage from bad source on Android): no
      // connectivity → pause + arm self-heal so the user's spot survives;
      // otherwise stop.
      _failedSkips = 0;
      if (!await hasConnectivity()) {
        await _localBackend.pause();
        _networkStalled = true;
      } else {
        _intentionalStop = true;
        await _localBackend.stop();
      }
      _broadcastState();
      return;
    }
    // Resume only if the user still wants playback: an upcoming track can
    // fail while PAUSED (preload), and the skip must not blast audio over a
    // deliberate pause.
    if (_playIntent) unawaited(_localBackend.play());
  }

  void _showPlaybackErrorToast(String message, {bool debounce = false}) {
    if (debounce) {
      final now = DateTime.now();
      if (_lastErrorToast != null &&
          now.difference(_lastErrorToast!) < _kErrorToastGap) {
        return;
      }
      _lastErrorToast = now;
    }
    showGlobalSnack(message);
  }

  // Recover from a non-iroh playback error. The decision needs an async
  // connectivity probe, so it runs serialized on _switchChain + guarded by
  // _recoveringPlayback / _skipPending (an error burst can't spin up concurrent
  // recoveries):
  //  • clearly bad source (404 / format / missing file) → skip now;
  //  • NO network (a real outage) → pause-and-hold + arm onNetworkRegained so we
  //    self-heal when it returns. This is the key fix: relying on the retry/skip
  //    counters to climb never paused, because a brief `ready` from the preload
  //    buffer kept resetting _httpRetries, so it spun in retries forever;
  //  • network up but the track errored (a transient blip) → retry the SAME track
  //    at its spot, bounded by _kMaxHttpRetries; once spent it's a bad source → skip.
  void _recoverHttpError(Object error) {
    if (_recoveringPlayback || _skipPending) return;
    // Clearly bad/unplayable source → skip now (no network probe / retry needed).
    if (!_isTransientNetworkError(error)) {
      _skipPending = true;
      _switchChain = _switchChain
          .then((_) => _skipFailedTrack(error))
          .catchError((Object e) =>
              castLog('skip-to-next after playback error failed', error: e))
          .whenComplete(() => _skipPending = false);
      return;
    }
    _recoveringPlayback = true;
    _switchChain = _switchChain.then((_) async {
      if (queue.value.isEmpty || !identical(_backend, _localBackend)) return;
      // No network → an outage: pause-and-hold and let onNetworkRegained resume
      // us when it's back, instead of churning retries/skips that all fail.
      if (!await hasConnectivity()) {
        appLog('[play] network outage — pausing at '
            'track ${(_localBackend.currentIndex ?? 0) + 1}; '
            'will self-heal when connectivity returns');
        _httpRetries = 0;
        _failedSkips = 0;
        _networkStalled = true;
        _showPlaybackErrorToast(
            'Lost the connection — paused. Resumes when you’re back online.');
        await _localBackend.pause();
        _broadcastState();
        return;
      }
      // Network is up but the track errored — a transient blip. Retry the SAME
      // track at its spot (bounded); once retries are spent it's a genuinely bad
      // source → skip.
      if (_httpRetries < _kMaxHttpRetries) {
        _httpRetries++;
        final attempt = _httpRetries;
        // 0s, then 1s, 2s — first retry immediate so a momentary blip recovers
        // fast; later ones give the connection a moment.
        await Future<void>.delayed(Duration(seconds: attempt - 1));
        if (queue.value.isEmpty || !identical(_backend, _localBackend)) return;
        // Read the spot AFTER the backoff so a skip/seek during the wait is
        // honoured, and load DIRECTLY at it (initialIndex/Position) so the
        // now-playing UI doesn't flash track 0 on the reload. _reviveSpot: a
        // failed launch restore parks at the SAVED spot, not the backend's 0.
        final spot = _reviveSpot();
        final pos = spot.position;
        final idx = spot.index;
        appLog('[play] network error — retry $attempt/$_kMaxHttpRetries');
        await _localBackend.setSources(queue.value,
            initialIndex: idx, initialPosition: pos);
        if (_playIntent) unawaited(_localBackend.play());
      } else {
        await _skipFailedTrack(error);
      }
    }).catchError((Object e) {
      castLog('http error recovery failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  // Resume after a queue-wide network stall when connectivity returns. Wired to
  // the app's connectivity listener (main.dart). No-op unless we actually paused
  // on a network outage (_networkStalled); resumes the current track at its spot
  // with the user's play intent.
  void onNetworkRegained() {
    if (!identical(_backend, _localBackend)) return;
    if (!_networkStalled || _recoveringPlayback) return;
    if (queue.value.isEmpty) return;
    _networkStalled = false;
    _httpRetries = 0;
    _recoveringPlayback = true;
    appLog('[play] connectivity back — resuming after network stall');
    // Keep-queue-offline: failed auto-downloads un-mark themselves, and this
    // is exactly the moment a retry can succeed — re-sweep (cheap no-op when
    // the setting is off or nothing needs fetching).
    unawaited(DownloadManager().autoDownloadQueue(queue.value));
    _switchChain = _switchChain
        .then((_) => _reseedLocalAtSpot())
        .catchError((Object e) {
      castLog('network-regained resume failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  /// Reload the local backend at its current spot, with every URL re-derived
  /// against the live tunnel/transcode state, then resume if the user still
  /// wants playback. The revive primitive for a parked player: once just_audio
  /// goes idle (a playback error tears the platform player down) a bare play()
  /// silently no-ops — only a re-seed brings audio back. _playIntent is read
  /// AFTER the load on purpose: setSources is network-bound (seconds over a
  /// just-reconnected tunnel) and a pause landing mid-load must win over the
  /// recovery that scheduled us. Callers serialize on _switchChain and hold
  /// _recoveringPlayback.
  Future<void> _reseedLocalAtSpot() async {
    if (!identical(_backend, _localBackend)) return;
    final fresh = _queueWithFreshUrls();
    if (fresh.isEmpty) return;
    final spot = _reviveSpot();
    final idx = spot.index.clamp(0, fresh.length - 1);
    // Load DIRECTLY at the spot (initialIndex/Position) so the now-playing UI
    // doesn't flash track 0 on the reload.
    await _localBackend.setSources(fresh,
        initialIndex: idx, initialPosition: spot.position);
    if (_playIntent) unawaited(_localBackend.play());
  }

  // Resume playback parked by an iroh server outage, fired on the tunnel's
  // not-connected → connected transition (listener in _init). The supervisor
  // heals a dropped tunnel in place — same loopback port — so the stored URLs
  // still look current and _ensureActiveTunnel's rebuild-on-restart never
  // runs; without this hook nothing reloads the player when the server
  // returns. Only touches a player that is actually parked: local backend,
  // idle without a deliberate stop, current track owned by the served server.
  IrohTunnelStatus? _lastTunnelStatus;
  // One-shot re-check for a connected edge that arrived while a transient
  // guard blocked the heal. The status subject emits on change only, so a
  // consumed edge never re-fires on its own — dropping it would park playback
  // until the user taps play.
  Timer? _tunnelHealRetry;
  void _onTunnelReconnected() {
    _tunnelHealRetry?.cancel();
    _tunnelHealRetry = null;
    if (!identical(_backend, _localBackend)) return;
    if (_intentionalStop) return;
    if (_recoveringPlayback || _skipPending) {
      _rearmTunnelHeal();
      return;
    }
    if (_localBackend.processingState != BackendProcessingState.idle) return;
    final q = queue.value;
    if (q.isEmpty) return;
    // _reviveSpot: after a failed launch restore the backend reads index 0 --
    // a mixed queue whose track 1 isn't iroh would never pass the gate below
    // even though the PARKED track's server just healed.
    final idx = _reviveSpot().index;
    final item = (idx >= 0 && idx < q.length) ? q[idx] : null;
    final server = item == null ? null : _serverFor(item);
    if (server == null || !server.isIroh) return;
    if (!ServerManager().tunnelServes(server)) return;
    // Shares the error-time recovery's per-server budget so a flapping tunnel
    // (connected↔reconnecting) can't spin reloads against a dying server.
    final now = DateTime.now();
    final last = _lastRecoveryByServer[server.localname];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      _rearmTunnelHeal();
      return;
    }
    _lastRecoveryByServer[server.localname] = now;
    _recoveringPlayback = true;
    appLog('[play] iroh tunnel back — resuming parked playback');
    // Keep-queue-offline: same retry moment as onNetworkRegained — a queued
    // iroh track's download URL only works while the tunnel serves.
    unawaited(DownloadManager().autoDownloadQueue(queue.value));
    _switchChain = _switchChain.then((_) async {
      // Re-check the park under the chain: something queued ahead of us (a
      // backend switch, a user play) may already have revived the player.
      if (_localBackend.processingState != BackendProcessingState.idle) return;
      await _reseedLocalAtSpot();
    }).catchError((Object e) {
      castLog('tunnel-reconnect resume failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  // Check the parked state again once the blocking guard has had time to
  // clear (the cooldown runs 10s; recoveries always finish). Terminates: a
  // healed player fails the idle guard and a still-dead tunnel fails
  // tunnelServes, and neither of those re-arms.
  void _rearmTunnelHeal() {
    _tunnelHealRetry =
        Timer(const Duration(seconds: 11), _onTunnelReconnected);
  }

  // Heuristic: does this error look like a clearly bad/unplayable source (skip
  // now) vs something worth retrying (a network/transport blip)? Best-effort and
  // platform-limited: on Android ExoPlayer reports almost everything — INCLUDING
  // 404s — as a generic "(0) Source error" and doesn't forward the real cause to
  // Dart, so most failures fall through to "retry" (bounded by _kMaxHttpRetries).
  // The needles below mainly catch iOS/web, where the message is richer. The real
  // outage-vs-bad-source decision for the END state is made by hasConnectivity().
  static bool _isTransientNetworkError(Object error) {
    final s = error.toString().toLowerCase();
    // Clear "bad/unplayable source" signals → not transient (skip, don't retry).
    const badSource = [
      'response code: 4', // 4xx (404/403/401…)
      'unsupported', 'no suitable', 'decoder', 'unrecognized',
      'malformed', 'file not found', 'does not exist',
    ];
    for (final m in badSource) {
      if (s.contains(m)) return false;
    }
    // Everything else (network/transport, generic "Source error") → retry.
    return true;
  }

  // Re-seed the inherited customState with a typed CustomEvent default (it
  // carries the AutoDJ server). Deliberately shadows BaseAudioHandler.customState.
  @override
  // ignore: overridden_fields
  BehaviorSubject<dynamic> customState =
      BehaviorSubject<dynamic>.seeded(CustomEvent(null));

  // True only while a queue reorder is rewiring the backend's source list.
  // moveAudioSource emits transient currentIndex values, so re-deriving the
  // now-playing MediaItem from queue.value[currentIndex] mid-reorder briefly
  // resolves to the *moved* item and flashes its art / title / waveform. The
  // playing track never changes during a reorder, so we hold the last good
  // MediaItem instead.
  bool _reordering = false;
  // True only while _doSetEqEnabled rebuilds the local player; suppresses the
  // currentIndexStream Auto-DJ top-up during the re-emit's index replay.
  bool _rebuilding = false;

  // Last item id logged by the [play] track-change diagnostic, so repeated
  // currentIndex emits for the same track don't spam the log.
  String? _lastPlayLoggedId;

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index > queue.value.length) return;
    // Explicit navigation supersedes a failed-restore park -- without this a
    // stale spot would hijack the next re-seed back to the old track.
    _restoreSpot = null;
    // This jumps to the beginning of the queue item at newIndex.
    _backend.seek(Duration.zero, index: index);
  }

  /// Reinstate a persisted queue at launch WITHOUT auto-playing: seed the queue
  /// + backend sources, park playback at [index]/[position] paused, and restore
  /// shuffle/repeat. Used by QueueStore.init() so the app reopens exactly where
  /// it left off. No-op for an empty list.
  Future<void> restoreQueue(List<MediaItem> items, int index, Duration position,
      {bool shuffle = false,
      AudioServiceRepeatMode repeat = AudioServiceRepeatMode.none}) async {
    if (items.isEmpty) return;
    // Wait for _init() to finish seeding the backend + applying EQ before our
    // own setSources(), so the two don't issue concurrent loads on the player
    // (which abort each other → "Loading interrupted", losing the restore).
    await _initialized.future;
    _intentionalStop = false;
    queue.add(items.toList());
    // Serialized on _switchChain: the re-seed paths (reload-on-play, tunnel
    // heal) chain their loads there, and an un-serialized restore load racing
    // one of them makes the two setSources abort each other ("Loading
    // interrupted"), losing the saved spot.
    final int i = index.clamp(0, items.length - 1);
    final done = _switchChain.then((_) async {
      try {
        await _backend.setSources(items);
        // play: false → load paused at the saved spot (don't blast audio on
        // open).
        await _backend.seek(position, index: i, play: false);
      } catch (e) {
        // A dead-server cold start (offline, stale tunnel loopback) makes the
        // load throw AFTER the queue is published — the player never reaches
        // the saved track, so its live index/position read 0. Don't lose the
        // user's spot: park it in _restoreSpot so the revive paths re-seed
        // THERE (not at track 1) and the next snapshot save doesn't persist
        // the loss. Repeat/shuffle below are player-level flags and still
        // apply without sources.
        _restoreSpot = (index: i, position: position);
        appLog('[queue] restore load failed — spot parked '
            '(track ${i + 1} @ ${position.inSeconds}s): $e');
      }
      _repeatMode = repeat;
      await _backend.setRepeat(_backendRepeat(repeat));
      if (shuffle) await _backend.setShuffleEnabled(true);
    });
    _switchChain = done.catchError((_) {});
    await done;
    _emitCurrentMediaItem();
    _broadcastState();
  }

  // Where a FAILED launch-restore load intended to park. Read by the revive
  // paths (they load here instead of the never-loaded backend's index 0) and
  // by QueueStore's snapshot writes (so a background save can't persist
  // track-1/0:00 over the real spot); cleared once any track reaches ready —
  // from then on the live player state is the truth.
  ({int index, Duration position})? _restoreSpot;
  ({int index, Duration position})? get restoreSpot => _restoreSpot;

  // The spot a revive/retry should load at: the parked failed-restore spot
  // when one is pending, else the backend's live position. The parked index
  // is clamped against the LIVE queue -- edits while parked can shrink it,
  // and an out-of-range index kills a reload (media3 throws on setSources'
  // initialIndex and silently no-ops the seek).
  ({int index, Duration position}) _reviveSpot() {
    final s = _restoreSpot;
    if (s == null) {
      return (
        index: _localBackend.currentIndex ?? 0,
        position: _localBackend.position
      );
    }
    final n = queue.value.length;
    return n == 0 ? s : (index: s.index.clamp(0, n - 1), position: s.position);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    queue.add(queue.value..add(mediaItem));
    // The backend extracts the playable URI (local backend) or builds renderer
    // metadata (cast backend) from the item itself. The offline-file detection
    // (File.existsSync + Uri.file) from the server-download-folder PR now lives
    // in LocalPlaybackBackend._uriFor.
    await _backend.addSource(mediaItem);
    appLog('[queue] add: ${mediaItem.title} (now ${queue.value.length})');
  }

  // The user's intended play state, tracked across just_audio errors (which flip
  // the backend's `playing` to false). A recovery uses this so a launch-time
  // re-seed resumes PAUSED rather than autoplaying on open.
  bool _playIntent = false;

  /// Whether play() must re-seed the local player instead of issuing a bare
  /// backend.play(): just_audio parked idle (a playback error tears the
  /// platform player down) with tracks still queued, so a bare play() would
  /// silently no-op. Never while a recovery is in flight — it re-seeds itself
  /// and reads the play intent when it does. Pure; unit-tested.
  static bool shouldReseedOnPlay({
    required bool onLocalBackend,
    required BackendProcessingState processingState,
    required bool queueEmpty,
    required bool recovering,
  }) =>
      onLocalBackend &&
      processingState == BackendProcessingState.idle &&
      !queueEmpty &&
      !recovering;

  // Completes when the launch queue restore has settled — restored, nothing
  // to restore (feature off / no snapshot / empty), or failed. Signalled by
  // QueueStore.init(); play() awaits it on a cold boot so a transport command
  // that beats the restore doesn't no-op on an empty player.
  final Completer<void> _restoreSettled = Completer<void>();
  Future<void> get queueRestoreSettled => _restoreSettled.future;
  void markQueueRestoreSettled() {
    if (!_restoreSettled.isCompleted) _restoreSettled.complete();
  }

  // Cold-boot resume race: a PLAY from the media-resumption chip, Bluetooth,
  // or Android Auto can reach a headless-booted service before QueueStore has
  // restored the saved queue — a bare play on an empty player silently no-ops
  // (the reseed net needs a non-empty queue). Trigger the restore ourselves
  // (both calls are idempotent; on a headless boot no widget may ever run
  // main.dart's initState trigger) and wait for it to settle. Bounded: the
  // settle can legitimately take tens of seconds (loadServerList dials an
  // iroh tunnel first), but a wedged startup must not hold the transport
  // forever.
  Future<void> _awaitQueueRestore() {
    unawaited(ServerManager()
        .ensureLoaded()
        .then((_) => QueueStore().init())
        .catchError((Object e) => appLog('[play] restore trigger failed: $e')));
    return queueRestoreSettled.timeout(const Duration(seconds: 60),
        onTimeout: () =>
            appLog('[play] queue restore never settled — playing as-is'));
  }

  @override
  Future<void> play() async {
    appLog('[play] play');
    _playIntent = true;
    _intentionalStop = false;
    if (queue.value.isEmpty && !_restoreSettled.isCompleted) {
      await _awaitQueueRestore();
      // The wait can run tens of seconds — a pause/stop that arrived during
      // it must win, not be overridden by this stale play when the restored
      // queue comes up. (pause() and stop() both clear _playIntent.)
      if (!_playIntent) return;
      // The restore parks paused at the saved spot; fall through so the bare
      // play (or the reseed net, if the restore load failed) resumes it.
    }
    if (shouldReseedOnPlay(
        onLocalBackend: identical(_backend, _localBackend),
        processingState: _backend.processingState,
        queueEmpty: queue.value.isEmpty,
        recovering: _recoveringPlayback)) {
      appLog('[play] play on an idle player — re-seeding sources');
      _recoveringPlayback = true;
      _switchChain = _switchChain
          .then((_) => _reseedLocalAtSpot())
          .catchError((Object e) => castLog('re-seed on play failed', error: e))
          .whenComplete(() => _recoveringPlayback = false);
      return _switchChain;
    }
    return _backend.play();
  }

  @override
  Future<void> pause() {
    appLog('[play] pause');
    _playIntent = false;
    return _backend.pause();
  }

  @override
  Future<void> skipToNext() async {
    _restoreSpot = null; // user navigation supersedes a failed-restore park
    _backend.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _restoreSpot = null; // user navigation supersedes a failed-restore park
    _backend.seekToPrevious();
  }

  @override
  Future<void> seek(Duration position) {
    // A manual scrub supersedes the parked position (keep nothing: the next
    // re-seed should read the live player, which this seek just updated).
    _restoreSpot = null;
    return _backend.seek(position);
  }

  // True while the handler itself is tearing playback down (user stop, cleared
  // queue, unplayable-queue give-up), so _broadcastState can tell a deliberate
  // idle apart from just_audio's error-induced idle. Cleared only at the
  // explicit restart entry points (play / restoreQueue) — NOT from observed
  // backend states, where a straggler ready event racing a stop could clear it
  // early and turn the stop's own idle into a bogus 'error' broadcast.
  bool _intentionalStop = false;

  @override
  Future<void> stop() async {
    appLog('[play] stop');
    _playIntent = false;
    _intentionalStop = true;
    // Don't touch the tunnel here: it follows the QUEUE, not the play/stop state,
    // so a stopped-but-still-queued iroh song keeps its tunnel (the queue listener
    // tears it down when the iroh songs are actually removed/cleared).
    await _backend.stop();
    await super.stop();
  }

  // Honor the requested mode: Android Auto and the lock screen send an absolute
  // target (not a toggle), and the in-app buttons already pass the desired mode.
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    // A transport toggle from Android Auto / the lock screen must never throw
    // out of the handler if the backend rejects the call (e.g. nothing loaded
    // yet on a cold headless bind); still re-broadcast the (unchanged) state.
    try {
      await _backend
          .setShuffleEnabled(shuffleMode == AudioServiceShuffleMode.all);
    } catch (e) {
      appLog('[audio] setShuffleMode failed: $e');
    }
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    try {
      await _backend.setRepeat(_backendRepeat(repeatMode));
    } catch (e) {
      appLog('[audio] setRepeatMode failed: $e');
    }
    _broadcastState();
  }

  // Map the audio_service repeat mode to what the backend models. 'group' has
  // no queue-group concept here, so it behaves as 'all'.
  static BackendRepeat _backendRepeat(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return BackendRepeat.one;
      case AudioServiceRepeatMode.none:
        return BackendRepeat.off;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return BackendRepeat.all;
    }
  }

  // ── Android Auto browsing (delegated to AutoBrowse). The native AudioService
  // IS the MediaBrowserService that Auto binds; these answer its browse/play
  // calls. They run headless (no UI), so AutoBrowse must self-bootstrap and
  // never throw — see auto_browse.dart.
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) =>
      AutoBrowse.children(parentMediaId);

  @override
  Future<MediaItem?> getMediaItem(String mediaId) =>
      AutoBrowse.mediaItem(mediaId);

  @override
  Future<void> playFromMediaId(String mediaId,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.play(mediaId);

  @override
  Future<List<MediaItem>> search(String query,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.search(query);

  // Google Assistant "play <X> on mStream" — advertised to the system via
  // MediaAction.playFromSearch in _broadcastState's systemActions.
  @override
  Future<void> playFromSearch(String query,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.playFromSearch(query);

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    await super.removeQueueItem(mediaItem);
    // TODO: See removeQueueItemAt
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    _restoreSpot = null; // row indices shift -- a parked index would lie
    await super.removeQueueItemAt(index);
    // Update the queue BEFORE the backend. removeSourceAt makes the backend emit
    // its new currentIndex, and the currentIndexStream listener re-derives the
    // now-playing item as queue.value[index]. If the queue still held the
    // removed item, the wrong row would briefly render as the active/playing row
    // (a flash in the accent colour) before correcting — same root cause as the
    // reorder flash. Reordering keeps the queue and the emitted index in sync.
    queue.add(queue.value..removeAt(index));
    await _backend.removeSourceAt(index);
  }

  /// The queue without [localname]'s items, plus the backend index playback
  /// should land on afterwards: the current item's new position when it
  /// survives, else the first survivor after it, else the last survivor.
  /// Returns null when no queued item belongs to [localname]. Pure; unit-tested.
  static ({List<MediaItem> keep, int newIndex, bool currentSurvives})?
      queueWithoutServer(
          List<MediaItem> queue, String localname, int currentIndex) {
    final keep = <MediaItem>[];
    int? newIndex;
    var currentSurvives = false;
    for (var i = 0; i < queue.length; i++) {
      final m = queue[i];
      if (m.extras?['server'] == localname) continue;
      if (i == currentIndex) {
        currentSurvives = true;
        newIndex = keep.length;
      } else if (i > currentIndex && !currentSurvives) {
        newIndex ??= keep.length;
      }
      keep.add(m);
    }
    if (keep.length == queue.length) return null;
    return (
      keep: keep,
      newIndex: keep.isEmpty ? 0 : (newIndex ?? keep.length - 1),
      currentSurvives: currentSurvives,
    );
  }

  /// Drop every queue item belonging to [localname] — its server was deleted.
  /// Downloaded copies stay on disk but leave the queue with the rest: their
  /// server context (ratings, art, URL re-resolution) went with the server.
  /// If the playing track was the server's, playback moves to the next
  /// surviving track (its stream URL just died with the server anyway).
  Future<void> removeServerQueueItems(String localname) async {
    if (autoDJServer?.localname == localname) {
      // Auto-DJ would keep topping the queue back up from the deleted server.
      autoDJServer = null;
      customState.add(CustomEvent(autoDJServer));
    }
    final q = queue.value;
    if (q.isEmpty) return;
    final cur = (_backend.currentIndex ?? 0).clamp(0, q.length - 1);
    final plan = queueWithoutServer(q, localname, cur);
    if (plan == null) return;
    appLog('[queue] server $localname removed — dropping '
        '${q.length - plan.keep.length} of its queued track(s)');
    _restoreSpot = null; // row indices shift — a parked index would lie
    if (plan.keep.isEmpty) {
      // The whole queue belonged to it: same teardown as clearPlaylist.
      _intentionalStop = true;
      await _backend.stop();
      await super.stop();
      await _backend.clearSources();
      queue.add(queue.value..clear());
      _broadcastState();
      return;
    }
    final pos = plan.currentSurvives ? _backend.position : Duration.zero;
    final wasPlaying = _backend.playing;
    final wasShuffle = _backend.shuffleEnabled;
    final wasRepeat = _backend.repeat;
    _reordering = true;
    try {
      queue.add(plan.keep);
      await _backend.setSources(plan.keep);
      await _backend.seek(pos, index: plan.newIndex, play: wasPlaying);
      // setSources rebuilds the playlist; re-apply shuffle/repeat so the
      // removal doesn't silently drop them (mirrors the transcode reload).
      await _backend.setShuffleEnabled(wasShuffle);
      await _backend.setRepeat(wasRepeat);
    } finally {
      _reordering = false;
    }
    _emitCurrentMediaItem();
    _broadcastState();
  }

  @override
  customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'clearPlaylist':
        appLog('[queue] cleared');
        _restoreSpot = null; // the queue the spot described is gone
        _intentionalStop = true;
        await _backend.stop();
        await super.stop();
        await _backend.clearSources();
        queue.add(queue.value..clear());
        _broadcastState();
        break;
      case 'moveQueueItem':
        // Drag-to-reorder. [to] is the post-removal target index
        // (ReorderableListView convention). Reorder the queue list first, then
        // the backend's source list, so the backend's current-index emit lands
        // against the already-updated queue.
        _restoreSpot = null; // row indices shift -- a parked index would lie
        final from = extras?['from'];
        final to = extras?['to'];
        if (from is int && to is int) {
          final q = queue.value;
          if (from >= 0 &&
              from < q.length &&
              to >= 0 &&
              to < q.length &&
              from != to) {
            final item = q.removeAt(from);
            q.insert(to, item);
            queue.add(q);
            // Hold the now-playing item steady while the backend rewires its
            // source order, so its art/title/waveform don't flash the moved
            // track as the backend's currentIndex transiently re-points.
            _reordering = true;
            try {
              await _backend.moveSource(from, to);
            } finally {
              _reordering = false;
            }
            _broadcastState();
          }
        }
        break;
      case 'updateRating':
        {
          // A track was (un)rated in the UI. Patch the new rating into the
          // matching queue items' extras and the now-playing item, so every
          // view that reads extras['rating'] (Song Info, the player readout)
          // reflects it and the persisted queue keeps it across a restart. The
          // server-side write is the rateSong POST; this only keeps the
          // in-memory queue / item in sync.
          final fp = extras?['filepath'] as String?;
          final srv = extras?['server'] as String?;
          if (fp != null) {
            final target = fp.startsWith('/') ? fp.substring(1) : fp;
            final newRating = (extras?['rating'] as num?)?.toInt();
            // Match the source server too (when supplied): a mixed-server queue
            // can carry the same path on two servers, and only the one that was
            // actually rated should change.
            bool hit(MediaItem m) {
              if (srv != null && m.extras?['server'] != srv) return false;
              final p = m.extras?['path'] as String?;
              return p != null &&
                  (p.startsWith('/') ? p.substring(1) : p) == target;
            }
            MediaItem patched(MediaItem m) =>
                m.copyWith(extras: {...?m.extras, 'rating': newRating});
            var changed = false;
            final nq = queue.value.map((m) {
              if (hit(m)) {
                changed = true;
                return patched(m);
              }
              return m;
            }).toList();
            if (changed) queue.add(nq);
            final cur = mediaItem.value;
            if (cur != null && hit(cur)) mediaItem.add(patched(cur));
          }
        }
        break;
      case 'forceAutoDJRefresh':
        customState.add(CustomEvent(autoDJServer));
        break;
      case 'setAutoDJ':
        if (autoDJServer == null || autoDJServer != extras?['autoDJServer']) {
          jsonAutoDJIgnoreList = null;
          _camelotAnchor = null;
          _autoDJAuthWarned = false; // fresh server, fresh warning budget
          _sonicHistory = const []; // fresh server, fresh sonic session
          _sonicWarned = false;
        }
        autoDJServer = extras?['autoDJServer'];

        customState.add(CustomEvent(autoDJServer));

        if (queue.value.isEmpty ||
            queue.value.length == 1 ||
            index == queue.value.length - 1) {
          if (queue.value.isEmpty) {
            await autoDJ(autoPlay: true);
            autoDJ();
          } else if (index == queue.value.length - 1 &&
              _backend.processingState == BackendProcessingState.idle) {
            autoDJ(autoPlay: true, incrementIndex: true);
          } else {
            autoDJ();
          }
        }

        break;
      case 'rebuildTranscodeUrls':
        await _rebuildTranscodeUrls(
            upcomingOnly: extras?['upcomingOnly'] == true,
            auto: extras?['auto'] == true);
        break;
    }
  }

  // Resolve a queue item's server from the localname stored in its extras.
  Server? _serverFor(MediaItem m) =>
      ServerManager().byLocalname(m.extras?['server'] as String?);

  /// Re-derive [m]'s stream URL under the CURRENT transcode settings. Returns
  /// the same instance when nothing changes, so callers can detect a no-op.
  /// Downloaded items are left alone — they play from the local copy, so their
  /// URL is irrelevant.
  MediaItem _withRebuiltUrl(MediaItem m) {
    if (m.extras?['localPath'] != null) return m;
    final path = m.extras?['path'] as String?;
    final server = _serverFor(m);
    if (path == null || server == null) return m; // local-only / unknown server
    final newId = buildServerStreamUrl(server, path);
    return sameStreamUrl(newId, m.id) ? m : m.copyWith(id: newId);
  }

  /// The URI the CURRENT item actually plays from: the downloaded file when
  /// one exists (mirroring LocalPlaybackBackend's source resolution), else the
  /// stream URL re-derived against the live tunnel / transcode state —
  /// `mediaItem.value.id` can carry a stale loopback port/token after a tunnel
  /// restart. Used by the visualizer's audio sidecar to decode what's playing.
  Uri? currentPlayableUri() {
    final m = mediaItem.value;
    if (m == null) return null;
    final localPath = m.extras?['localPath'] as String?;
    if (localPath != null && File(localPath).existsSync()) {
      return Uri.file(localPath);
    }
    return Uri.tryParse(_withRebuiltUrl(m).id);
  }

  /// Rebuild queue stream URLs after a transcode-setting change ([auto] false)
  /// or a tunnel (re)connect ([auto] true, fired by ServerManager).
  ///
  /// [upcomingOnly] leaves the current track playing and only swaps the
  /// not-yet-played tracks; otherwise the whole queue reloads at the current
  /// index/position (the current track briefly re-buffers). No-op when no URL
  /// actually changes (e.g. nothing to convert, or transcoding unavailable).
  Future<void> _rebuildTranscodeUrls(
      {required bool upcomingOnly, bool auto = false}) async {
    // An auto rebuild must not touch an active cast: the cast backends
    // re-resolve every track's URL at load time (irohProxyUri rebinds to the
    // live tunnel), so the reload is unnecessary — and issuing it mid-session
    // clobbers the Cast SDK's own suspend/resume recovery (observed
    // on-device: zombie TV + double audio after a Wi-Fi blip). A user-driven
    // transcode change still applies while casting.
    if (auto && !identical(_backend, _localBackend)) {
      appLog('[queue] auto URL rebuild skipped while casting');
      return;
    }
    final q = queue.value;
    if (q.isEmpty) return;
    final cur = (_backend.currentIndex ?? 0).clamp(0, q.length - 1);

    if (upcomingOnly) {
      final rebuilt = <MediaItem>[];
      bool changed = false;
      for (int i = 0; i < q.length; i++) {
        if (i <= cur) {
          rebuilt.add(q[i]);
        } else {
          final nm = _withRebuiltUrl(q[i]);
          if (!identical(nm, q[i])) changed = true;
          rebuilt.add(nm);
        }
      }
      if (!changed) return;
      _reordering = true;
      try {
        // Swap the upcoming sources without touching the playing one: drop them
        // from the end, then re-append the rebuilt versions in the same order.
        for (int i = q.length - 1; i > cur; i--) {
          await _backend.removeSourceAt(i);
        }
        for (int i = cur + 1; i < rebuilt.length; i++) {
          await _backend.addSource(rebuilt[i]);
        }
        queue.add(rebuilt);
      } finally {
        _reordering = false;
      }
    } else {
      final rebuilt = q.map(_withRebuiltUrl).toList();
      bool changed = false;
      for (int i = 0; i < q.length; i++) {
        if (!identical(rebuilt[i], q[i])) changed = true;
      }
      if (!changed) return;
      appLog('[queue] stream URLs rebuilt — reloading at track ${cur + 1}'
          '${auto ? ' (auto)' : ''}');
      final pos = _backend.position;
      final wasPlaying = _backend.playing;
      final wasShuffle = _backend.shuffleEnabled;
      final wasRepeat = _backend.repeat;
      _reordering = true;
      try {
        queue.add(rebuilt);
        await _backend.setSources(rebuilt);
        await _backend.seek(pos, index: cur, play: wasPlaying);
        // setSources rebuilds the playlist; re-apply shuffle/repeat so a
        // transcode change doesn't silently drop them (mirrors restoreQueue).
        await _backend.setShuffleEnabled(wasShuffle);
        await _backend.setRepeat(wasRepeat);
      } finally {
        _reordering = false;
      }
    }
    _emitCurrentMediaItem();
    _broadcastState();
  }

  /// The queue with every copy of [serverName]+[path] patched to play from
  /// [localPath], or null when nothing needed patching (not queued, or every
  /// copy already carries this exact path). A copy holding a DIFFERENT
  /// localPath is re-patched — after a storage-location change the old path
  /// is stale and the re-download landed somewhere new. Untouched items keep
  /// their instances. Pure; unit-tested.
  static List<MediaItem>? patchDownloadedTrack(List<MediaItem> queue,
      {required String serverName,
      required String path,
      required String localPath}) {
    var changed = false;
    final patched = queue.map((m) {
      final e = m.extras;
      if (e == null ||
          e['server'] != serverName ||
          e['path'] != path ||
          e['localPath'] == localPath) {
        return m;
      }
      changed = true;
      return m.copyWith(extras: {...e, 'localPath': localPath});
    }).toList();
    return changed ? patched : null;
  }

  /// A finished download for [serverName]+[path] landed at [localPath]: mark
  /// the queued copies of that track as local. Extras-only ON PURPOSE — no
  /// live source surgery (removing/re-adding loaded sources mid-play races
  /// un-serialized queue edits, re-rolls shuffle order, and can trip the
  /// completed→stop teardown). The patched extras are what every fresh LOAD
  /// reads (LocalPlaybackBackend._uriFor at setSources; resolveRendererUri
  /// when a cast session (re)seeds), so: the badge lights up now, the
  /// snapshot persists it, restores / re-seeds / return-to-local reloads and
  /// the next cast session play from disk — and if an already-loaded
  /// streaming source dies offline, the retry re-seed lands on the file
  /// within seconds. Sources already loaded (local playlist, live cast item
  /// list) simply finish their session streaming. Synchronous — no awaits
  /// between reading and publishing the queue, so it can't interleave with
  /// anything.
  void onTrackDownloaded(String serverName, String path, String localPath) {
    final patched = patchDownloadedTrack(queue.value,
        serverName: serverName, path: path, localPath: localPath);
    if (patched == null) return;
    appLog('[queue] download landed — queued copies of '
        '${path.split('/').last} marked local');
    // The PLAYING track keeps streaming its already-loaded source until the
    // next load, but its extras now say "local" — hold the WifiLock until a
    // fresh load actually reads the file (cleared on `loading`), or the
    // screen-off power-save stall the lock prevents comes right back.
    if (identical(_backend, _localBackend) &&
        _backend.processingState != BackendProcessingState.idle) {
      final q = queue.value;
      final cur = _backend.currentIndex ?? 0;
      if (cur >= 0 && cur < q.length && !identical(patched[cur], q[cur])) {
        _currentSourcePredatesPatch = true;
      }
    }
    queue.add(patched);
    _updateWifiLock();
  }

  // True while the CURRENT item's extras say "local" but its loaded source
  // was created before the download landed and still streams. Only consulted
  // by the WifiLock heuristics; cleared when any fresh load starts.
  bool _currentSourcePredatesPatch = false;

  /// The processing state to publish for the backend's [state]. A deliberate
  /// teardown (intentional stop, or nothing queued) passes `idle` through —
  /// audio_service stops the Android service on every published
  /// non-idle→idle transition, which is exactly right there. But just_audio
  /// also flips to `idle` on ANY playback error; publishing that would let
  /// audio_service stopSelf() while the UI activity is unbound (backgrounded /
  /// swiped away), destroying the FlutterEngine before the error recovery in
  /// _onPlaybackError can run. An unintentional idle with tracks still queued
  /// publishes `error` instead, keeping the service (and notification) alive.
  static AudioProcessingState publishProcessingState(
      BackendProcessingState state,
      {required bool intentionalStop,
      required bool queueEmpty}) {
    switch (state) {
      case BackendProcessingState.idle:
        return (intentionalStop || queueEmpty)
            ? AudioProcessingState.idle
            : AudioProcessingState.error;
      case BackendProcessingState.loading:
        return AudioProcessingState.loading;
      case BackendProcessingState.buffering:
        return AudioProcessingState.buffering;
      case BackendProcessingState.ready:
        return AudioProcessingState.ready;
      case BackendProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Broadcasts the current state to all clients.
  /// Whether the Android WifiLock should be held: the phone is actively
  /// moving audio bytes over the network. Either the local player is playing
  /// a network source, or a cast renderer is being fed FROM the phone (iroh
  /// LAN relay, local-file serve, visualizer HLS — LocalMediaServer moves
  /// every byte, so radio power-save starves the TV just the same; a
  /// plain-HTTP cast streams renderer-direct and doesn't need it). Never for
  /// on-disk files and never while paused, stopped, or parked — a silent
  /// player holding a full-power Wi-Fi lock for hours is a battery bug, and
  /// the tunnel heal works without it. Pure; unit-tested.
  static bool shouldHoldWifiLock({
    required bool playing,
    required bool onLocalBackend,
    required BackendProcessingState processingState,
    required bool itemIsNetworkSource,
    required bool castRelaysViaPhone,
  }) {
    if (!playing) return false;
    if (castRelaysViaPhone) return true;
    return onLocalBackend &&
        itemIsNetworkSource &&
        processingState != BackendProcessingState.idle &&
        processingState != BackendProcessingState.completed;
  }

  // Whether the LOCAL backend actually pulls [item] over the network. Mirrors
  // LocalPlaybackBackend._uriFor: a downloaded track plays from disk only
  // while its file still exists — gone (SD ejected, folder cleared) it falls
  // back to streaming the id, which needs the lock like any other stream.
  static bool _streamsFromNetwork(MediaItem item) {
    if (!item.id.startsWith('http://') && !item.id.startsWith('https://')) {
      return false;
    }
    final localPath = item.extras?['localPath'] as String?;
    return localPath == null || !File(localPath).existsSync();
  }

  // Whether a cast renderer fetches [item] FROM THE PHONE rather than from a
  // server. Mirrors resolveRendererUri (cast_origin.dart): a local-only file
  // is served by LocalMediaServer, an iroh track is relayed through its proxy
  // (or disk-served); only a plain-HTTP server track goes renderer-direct.
  bool _phoneIsCastOrigin(MediaItem item) {
    final localPath = item.extras?['localPath'] as String?;
    final isNetwork =
        item.id.startsWith('http://') || item.id.startsWith('https://');
    if (!isNetwork && localPath != null && File(localPath).existsSync()) {
      return true;
    }
    return _serverFor(item)?.isIroh ?? false;
  }

  // True while the active cast backend streams the on-device visualizer: the
  // phone transcodes and serves the HLS itself, so it is the renderer's byte
  // origin regardless of where the track's audio came from. Set on every cast
  // switch; only consulted while a cast backend is active.
  bool _castVisualizer = false;

  // Re-evaluated on every state broadcast (play/pause, track change, backend
  // swap, processing-state moves all land there); the shim dedupes, so only
  // actual transitions cross the platform channel.
  void _updateWifiLock() {
    final q = queue.value;
    final idx = _backend.currentIndex ?? 0;
    final item = (idx >= 0 && idx < q.length) ? q[idx] : null;
    final onLocal = identical(_backend, _localBackend);
    unawaited(WifiLockShim.setHeld(shouldHoldWifiLock(
      playing: _backend.playing,
      onLocalBackend: onLocal,
      processingState: _backend.processingState,
      // _currentSourcePredatesPatch: extras say "local" but the loaded source
      // still streams (download landed mid-track) — keep the lock honest.
      itemIsNetworkSource: item != null &&
          (_streamsFromNetwork(item) || _currentSourcePredatesPatch),
      castRelaysViaPhone: !onLocal &&
          item != null &&
          (_castVisualizer || _phoneIsCastOrigin(item)),
    )));
  }

  void _broadcastState() {
    // Mid-rebuild reads go through the NEW empty player and would publish a
    // bogus transient `error`; _doSetEqEnabled broadcasts once it's done.
    if (_rebuilding) return;
    _updateWifiLock();
    final playing = _backend.playing;
    final AudioServiceShuffleMode shuffle = _backend.shuffleEnabled == true
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;

    // Emit the exact requested mode (_repeatMode); the backend's BackendRepeat
    // collapses 'group' to 'all', so reading it back would lose information.
    // This keeps none/all/one distinct for clients that cycle through them.
    final AudioServiceRepeatMode repeat = _repeatMode;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        // Lets Google Assistant route "play <X> on mStream" to playFromSearch.
        MediaAction.playFromSearch,
      },
      shuffleMode: shuffle,
      repeatMode: repeat,
      androidCompactActionIndices: [0, 1, 3],
      processingState: publishProcessingState(_backend.processingState,
          intentionalStop: _intentionalStop,
          queueEmpty: queue.value.isEmpty),
      playing: playing,
      updatePosition: _backend.position,
      bufferedPosition: _backend.bufferedPosition,
      speed: _backend.speed,
      queueIndex: _backend.currentIndex,
    ));
  }

  Future<void> autoDJ(
      {bool autoPlay = false, bool incrementIndex = false}) async {
    if (autoDJServer == null) return;

    // Build per-call ignoreVPaths once (cheap, doesn't change across
    // retry attempts).
    final ignoreVPaths = <String>[];
    autoDJServer!.autoDJPaths.forEach((key, value) {
      if (value == false) ignoreVPaths.add(key);
    });

    final mgr = AutoDJManager();
    Map<String, dynamic>? lastDecoded;

    // BPM/key continuity reads the currently playing item once per
    // call. If extras don't carry bpm/musicalKey (e.g. a localFile or
    // a browse hit without metadata), the windows aren't sent and the
    // server picks freely.
    final currentItem = (index != null &&
            index! >= 0 &&
            index! < queue.value.length)
        ? queue.value[index!]
        : null;
    final rawBpm = currentItem?.extras?['bpm'];
    final currentBpm = rawBpm is num ? rawBpm.round() : null;
    final currentKey = currentItem?.extras?['musicalKey'] as String?;

    // If harmonic mixing is on and we have no anchor yet, try to
    // seed it from the currently playing item's key. Otherwise the
    // first DJ pick locks the anchor (see _queueAutoDJSong below).
    if (mgr.harmonicMixingEnabled && _camelotAnchor == null) {
      final seed = toCamelotCode(currentKey);
      if (seed != null) _camelotAnchor = seed;
    }

    // Sonic similarity: constrain the pick pool to tracks within the
    // session's vibe — server-side, via `similarTo` + `minSimilarity` on
    // random-songs itself. The sonic pool is a HARD base constraint there
    // (the BPM/key waterfall relaxes WITHIN it, and ignoreList / rating /
    // genre filters compose as usual). Seeds follow the webapp's rolling
    // anchor: the last few DJ picks (session centroid), else the playing
    // track; a cold start on an empty queue has no anchor and stays plain
    // random until the first pick seeds the session.
    final sonic = sonicParams(
      enabled: mgr.sonicSimilarityEnabled &&
          autoDJServer!.discoveryAvailable == true,
      history: _sonicHistory,
      currentPath: currentItem?.extras?['server'] == autoDJServer!.localname
          ? (currentItem?.extras?['path'] as String?)
          : null,
      minSimilarity: mgr.sonicMinSimilarity,
    );

    // Keyword filter is client-side (the server doesn't see it).
    // Retry up to 5 times if responses get blocked, using the
    // updated ignoreList from the server so we don't pick the same
    // rejected track twice. After 5 blocks accept the last response
    // anyway — mirrors the webapp's fallback so the queue doesn't
    // stall forever on an over-aggressive filter.
    for (var attempt = 0; attempt < 5; attempt++) {
      final payload = <String, dynamic>{
        'ignoreList': jsonAutoDJIgnoreList ?? [],
        ...?sonic,
      };
      if (autoDJServer!.autoDJminRating != null) {
        payload['minRating'] = autoDJServer!.autoDJminRating;
      }
      if (ignoreVPaths.isNotEmpty) {
        payload['ignoreVPaths'] = ignoreVPaths;
      }
      if (mgr.genreFilterEnabled && mgr.genreFilterValues.isNotEmpty) {
        payload['genres'] = mgr.genreFilterValues;
        payload['genreMode'] = mgr.genreFilterMode;
      }
      if (mgr.bpmContinuityEnabled && currentBpm != null && currentBpm > 0) {
        payload['bpmRanges'] =
            _bpmWindows(currentBpm, mgr.bpmTolerance);
        payload['bpmRangesWide'] =
            _bpmWindows(currentBpm, mgr.bpmTolerance + 2);
        // Require tagged tracks so the waterfall doesn't fall back
        // to BPM-unknown picks when our windows return nothing.
        payload['requireBpm'] = true;
      }
      if (mgr.harmonicMixingEnabled) {
        if (_camelotAnchor != null) {
          payload['musicalKeys'] = camelotNeighbours(_camelotAnchor!);
        }
        // Always prefer tagged tracks when harmonic mode is on —
        // even without an anchor, the first pick should be keyed so
        // we can lock the anchor for the rest of the session.
        payload['requireMusicalKey'] = true;
      }

      Map<String, dynamic> decoded;
      try {
        // Bounded like every other headless fetch so a black-hole server (e.g.
        // a Shuffle All started from Android Auto, which awaits this) can't hang
        // forever; the catch below treats the TimeoutException as a network
        // error and bails silently.
        final res = await http.post(
          autoDJServer!.apiUri('/api/v1/db/random-songs'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': autoDJServer?.jwt ?? '',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode > 299) {
          appLog('[dj] random-songs HTTP ${res.statusCode} — pick skipped');
          // Sonic mode fails LOUD by the server's contract: the pool is a
          // hard promise ("only songs within X of the vibe"), so an empty
          // pool or an unanalyzed seed stops the session with an
          // explanation instead of silently playing outside the range
          // (webapp parity — it discriminates on the error message too).
          if (sonic != null) {
            String serverMsg = '';
            try {
              final b = jsonDecode(res.body);
              if (b is Map && b['error'] is String) serverMsg = b['error'];
            } catch (_) {}
            final lower = serverMsg.toLowerCase();
            if (lower.contains('similarity range')) {
              if (!_sonicWarned) {
                _sonicWarned = true;
                _showPlaybackErrorToast(
                    'Auto DJ: no songs are within the similarity range. '
                    'Loosen the match slider or adjust your filters.');
              }
              return;
            }
            if (lower.contains('analyzed')) {
              if (!_sonicWarned) {
                _sonicWarned = true;
                _showPlaybackErrorToast(
                    "Auto DJ: this song hasn't been analyzed yet — wait "
                    'for the discovery scan or play a different song.');
              }
              return;
            }
            // requireIndex 403 ("Discovery is disabled"): the capability
            // vanished since the last ping — NOT an expired login, so it
            // must not fall through to the re-login toast below.
            if (lower.contains('discovery is disabled')) {
              return;
            }
          }
          // An expired/rotated JWT kills Auto DJ permanently and used to do it
          // in total silence — infinite play just stopped. Tell the user once.
          if ((res.statusCode == 401 || res.statusCode == 403) &&
              !_autoDJAuthWarned) {
            _autoDJAuthWarned = true;
            _showPlaybackErrorToast(
                'Auto DJ stopped — the server session expired. '
                'Re-login in Manage Servers.');
          }
          return;
        }
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
        // A working pick re-arms the auth warning: the once-per-session flag
        // exists to collapse queue-end retrigger spam of ONE expiry episode,
        // not to silence a NEW expiry after a recovery. Same for the sonic
        // fail-loud toast.
        _autoDJAuthWarned = false;
        _sonicWarned = false;
      } catch (e) {
        // Network error → bail without a toast (an offline queue-end is
        // normal), but leave a trace for Diagnostics.
        appLog('[dj] random-songs failed: $e');
        return;
      }

      jsonAutoDJIgnoreList = decoded['ignoreList'];
      final songs = decoded['songs'] as List?;
      if (songs == null || songs.isEmpty) return;

      lastDecoded = decoded;

      if (!mgr.isKeywordBlocked(songs[0] as Map<String, dynamic>)) {
        _queueAutoDJSong(decoded,
            autoPlay: autoPlay, incrementIndex: incrementIndex);
        return;
      }
      // Otherwise loop — the updated ignoreList means the next call
      // returns a different candidate.
    }

    if (lastDecoded != null) {
      _queueAutoDJSong(lastDecoded,
          autoPlay: autoPlay, incrementIndex: incrementIndex);
    }
  }

  void _queueAutoDJSong(Map<String, dynamic> decoded,
      {bool autoPlay = false, bool incrementIndex = false}) {
    final song = decoded['songs'][0] as Map<String, dynamic>;
    final metadata = (song['metadata'] as Map?) ?? const {};
    final filepath = song['filepath'] as String?;
    if (filepath == null) return; // skip a degenerate random-songs row

    // Transcode-aware stream URL (honors the /transcode endpoint + codec/bitrate
    // when transcoding is on), shared with browse / queue-restore / recursive.
    final mediaUrl = buildServerStreamUrl(autoDJServer!, filepath);

    final artUrl = metadata['album-art'] != null
        ? buildAlbumArtUrl(autoDJServer!, metadata['album-art'] as String,
            compress: 'l')
        : null;

    // Parse the raw server map once so the genre / disc / key wire quirks are
    // handled in one place (MusicMetadata.fromServerMap) — the same path that
    // browse-added items take.
    final meta = MusicMetadata.fromServerMap(metadata);
    final item = MediaItem(
      id: mediaUrl,
      title: meta.title ?? filepath.split('/').last,
      album: meta.album,
      artist: meta.artist,
      genre: meta.genreLabel,
      // Duration from the server payload (browse-added parity). Without it a
      // restore of an Auto-DJ track can't clamp a saved at-the-end position
      // (see QueueStore.clampResumePositionMs) — reopening then seeks past
      // the end, completes, and playback "won't start".
      duration: meta.duration,
      // Artwork for the notification / lock screen / Android Auto (see
      // buildServerFileMediaItem — artUri mirrors extras['artUrl']).
      artUri: artUrl == null ? null : Uri.parse(artUrl),
      extras: {
        // Tag with the source server so Share Playlist's multi-server
        // detection recognises AutoDJ-added songs as shareable.
        'server': autoDJServer!.localname,
        'path': filepath,
        // Server-side per-user rating, so an AutoDJ-added track shows + persists
        // its rating the same as a browse-added one.
        'rating': meta.rating,
        'year': meta.year,
        'track': meta.track,
        'disc': meta.disc,
        'artUrl': artUrl,
        // bpm + musicalKey power the next AutoDJ pick's continuity payload
        // (see autoDJ() above), stashed under our camelCase keys for
        // consistency with browser-added items.
        'bpm': meta.bpm,
        'musicalKey': meta.musicalKey,
      },
    );

    // Lock the Camelot anchor on the first keyed DJ pick of the
    // session. Subsequent calls in autoDJ() will use the anchor's
    // neighbours rather than re-deriving from each newly-played
    // song's key (which would drift across the session).
    if (AutoDJManager().harmonicMixingEnabled && _camelotAnchor == null) {
      final code = toCamelotCode(metadata['musical-key'] as String?);
      if (code != null) _camelotAnchor = code;
    }

    addQueueItem(item);

    // Feed the rolling sonic anchor with every DJ pick (kept even while the
    // mode is off, so toggling it on mid-session already has the session's
    // recent sound to centroid on).
    _sonicHistory = pushSonicHistory(_sonicHistory, filepath);

    if (incrementIndex == true && index != null) {
      _backend.seek(Duration.zero, index: index! + 1);
    }
    if (autoPlay == true) {
      play();
    }
  }

  /// The `similarTo`/`minSimilarity` fields for a random-songs body, or
  /// null when sonic mode is off / no anchor is resolvable (cold start on
  /// an empty queue — the pick stays plain random and then seeds the
  /// session). Rolling-anchor policy, mirroring the webapp's
  /// auto-dj.js buildSonicParams: the recent DJ picks (server averages
  /// them into a session centroid), else the playing track. Pure;
  /// unit-tested.
  static Map<String, dynamic>? sonicParams({
    required bool enabled,
    required List<String> history,
    String? currentPath,
    required double minSimilarity,
  }) {
    if (!enabled) return null;
    if (history.isNotEmpty) {
      return {
        'similarTo': List<String>.of(history),
        'minSimilarity': minSimilarity,
      };
    }
    final cur = _normSonicPath(currentPath);
    if (cur == null) return null;
    return {
      'similarTo': [cur],
      'minSimilarity': minSimilarity,
    };
  }

  /// Appends a DJ pick to the rolling sonic ring buffer: normalized,
  /// deduped (a re-pick moves to the most-recent slot rather than
  /// double-weighting the server's centroid), capped at [limit] — the
  /// webapp keeps 5 of the up-to-8 seeds the server accepts. Pure;
  /// unit-tested.
  static List<String> pushSonicHistory(List<String> history, String? rawPath,
      {int limit = 5}) {
    final norm = _normSonicPath(rawPath);
    if (norm == null) return history;
    final next = [
      for (final p in history)
        if (p != norm) p,
      norm,
    ];
    while (next.length > limit) {
      next.removeAt(0);
    }
    return next;
  }

  /// Seed paths on the wire never carry a leading slash (they resolve via
  /// getVPathInfo server-side); queue extras' paths do. Normalize at every
  /// write/build point, like the webapp's _normSonicPath.
  static String? _normSonicPath(String? p) {
    if (p == null) return null;
    final s = p.startsWith('/') ? p.substring(1) : p;
    return s.isEmpty ? null : s;
  }

  // BPM continuity windows: one centered on the current tempo, one
  // at half-tempo, one at double. The server OR-s these together so
  // a 120-BPM source matches tracks at 112–128, 56–64, or 232–248
  // (with tolerance=8). Half/double cover the common DJ practice
  // of mixing across octaves.
  static List<Map<String, int>> _bpmWindows(int bpm, int tolerance) {
    final half = (bpm / 2).round();
    final dbl = bpm * 2;
    return [
      {'min': bpm - tolerance, 'max': bpm + tolerance},
      {'min': half - tolerance, 'max': half + tolerance},
      {'min': dbl - tolerance, 'max': dbl + tolerance},
    ];
  }
}
