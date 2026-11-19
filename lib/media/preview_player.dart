// The 30-second clips on the network-lead sheet ("More like this" › From
// the network), played on a second just_audio player beside the song's.
//
// The clip never enters the audio handler: it is no PlaybackBackend, has no
// MediaItem and is never registered with audio_service. Play history (and so
// the server's scrobbles), the widget, CarPlay, Android Auto and the lock
// screen all read the handler alone, so they keep showing the real song,
// paused, and pressing Play there resumes it and stops the clip.
//
// One clip at a time. The song is paused through the handler only once the
// clip has loaded, so a slow CDN never leaves the user in silence, and it is
// resumed through the handler only when this flow paused it and nobody has
// touched it since: no transport command (media/transport_log.dart), the
// same track, the same cast target, and not playing already. A switch to
// another provider's clip keeps the song paused in between. While casting,
// the cast is paused and resumed the same way (the handler's pause and play
// work on every backend); the clip itself plays on the phone.
//
// Nothing here reads MediaManager, CastManager or the audio session before
// the first play(), and end() with nothing playing does nothing. Widget
// tests that pump the sheet (whose dispose ends the preview) install a fake
// in PreviewPlayer.instance; see test/media/preview_fakes.dart.

import 'dart:async';

import 'package:audio_session/audio_session.dart'
    show AudioInterruptionEvent, AudioInterruptionType, AudioSession;
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:just_audio/just_audio.dart'
    show AudioPlayer, AudioSource, ProcessingState;
import 'package:rxdart/rxdart.dart';

import '../singletons/cast_manager.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import 'audio_stuff.dart' show AudioPlayerHandler;
import 'transport_log.dart';

enum PreviewPhase { idle, loading, playing, failed }

/// What the sheet draws: whose clip, and how far into it.
@immutable
class PreviewClipState {
  const PreviewClipState({
    this.provider,
    this.phase = PreviewPhase.idle,
    this.position = Duration.zero,
    this.duration,
  });

  static const PreviewClipState idle = PreviewClipState();

  /// The preview plug-in whose clip this is ('deezer', 'itunes'); null
  /// while idle.
  final String? provider;
  final PreviewPhase phase;

  /// How far the clip has played; zero until it plays.
  final Duration position;

  /// The clip's length once the player knows it. The sheet falls back to
  /// the answer's `seconds` until then.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is PreviewClipState &&
      other.provider == provider &&
      other.phase == phase &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(provider, phase, position, duration);

  @override
  String toString() =>
      'PreviewClipState(${phase.name}, $provider, $position / $duration)';
}

/// Why a preview flow ended; [PreviewPlayer.resumesSong] decides from it
/// whether the song comes back.
enum PreviewEnd {
  /// The clip played to its end.
  completed,

  /// The user tapped the playing tile (the clip stops and resets).
  stopped,

  /// The sheet closed.
  sheetClosed,

  /// The app went to the background.
  backgrounded,

  /// A store or web link is opening: the user is heading into another app,
  /// often another music app, so the song stays paused.
  leftApp,

  /// The clip would not load or broke while playing.
  failed,

  /// The song started: Play on the lock screen, CarPlay, a headset, the mini
  /// player, or the song resuming by itself.
  songStarted,

  /// The song was paused or stopped by someone else: the sleep timer, Siri
  /// or Assistant, the handler's own becoming-noisy pause (or, rarely, its
  /// queue-end stop; see media/transport_log.dart).
  songTouched,

  /// A call, an alarm or another app took the audio.
  interrupted,

  /// Headphones came out or a Bluetooth output dropped.
  outputLost,
}

enum PreviewPlayOutcome {
  playing,
  failed,

  /// A newer play or an end arrived while this one loaded; it did nothing.
  superseded,
}

/// The song a flow paused: its track key, the transport number of the
/// flow's own pause, and the cast target it was playing on.
typedef SongHold = ({String? key, int epoch, String target});

/// The song's side, as the preview player sees it: the audio handler, the
/// cast manager, the app-wide audio session and the app's lifecycle. The
/// app's is [AppPreviewPort]; tests drive a fake.
abstract class PreviewPort {
  /// The song is playing (or buffering towards it) now.
  bool get songPlaying;

  /// The current track's identity (AudioPlayerHandler.trackKey).
  String? get songKey;

  /// The active cast target's id (the local device's when not casting).
  String get castTarget;
  bool get casting;

  /// TransportLog.epoch: read right after [pauseSong] to learn the number
  /// that pause got.
  int get transportEpoch;
  Stream<TransportCommand> get transportCommands;

  /// The song's playing flag, distinct; may replay the current value first.
  Stream<bool> get playingChanges;
  Stream<String?> get songKeyChanges;
  Stream<String> get castTargetChanges;
  Stream<AudioInterruptionEvent> get interruptions;
  Stream<void> get becomingNoisy;

  /// Each time the app goes to the background (not the passing inactive
  /// state of a system sheet or the app switcher).
  Stream<void> get appHidden;

  Future<void> pauseSong();

  /// Resumes the song. Never awaited inside: the handler's play completes
  /// only when playback next pauses.
  void playSong();
}

/// One clip player, reused across clips until the sheet closes.
abstract class PreviewClip {
  Future<void> load(Uri url);

  /// Starts the loaded clip; returns at once.
  void play();
  Future<void> stop();
  Future<void> dispose();
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<void> get completed;
  Stream<Object> get errors;
}

class PreviewPlayer {
  /// The app's preview player.
  factory PreviewPlayer() => instance;

  /// Widget tests that pump a sheet playing or ending previews put a fake
  /// here, and put the app's back in tearDown ([reset]) next to
  /// DiscoveryKeepRoutes.reset() and YtdlHub.reset().
  @visibleForTesting
  static PreviewPlayer instance = PreviewPlayer.withPort(AppPreviewPort());

  /// A fresh app player in [instance] (tests).
  @visibleForTesting
  static void reset() => instance = PreviewPlayer.withPort(AppPreviewPort());

  PreviewPlayer.withPort(
    this._port, {
    PreviewClip Function()? makeClip,
    this.loadTimeout = const Duration(seconds: 15),
  }) : _makeClip = makeClip ?? JustAudioPreviewClip.new;

  final PreviewPort _port;
  final PreviewClip Function() _makeClip;

  /// How long a clip may take to load before its row reads as unavailable.
  final Duration loadTimeout;

  final BehaviorSubject<PreviewClipState> _state =
      BehaviorSubject<PreviewClipState>.seeded(PreviewClipState.idle);

  // Made on the first play, disposed when the sheet closes.
  PreviewClip? _clip;

  // Bumped by every play and by every end of a flow: a play that comes back
  // from an await to a different number was superseded.
  int _gen = 0;

  // A flow runs from a play until its end. Switching clips stays in one.
  bool _active = false;

  // The song this flow paused, until the flow ends or something drops it.
  SongHold? _hold;

  // The hold's pause until it lands: the song still reads as playing then,
  // though it is about to be paused.
  Future<void>? _pausing;

  // Transport commands numbered up to this are older than the flow; the
  // pauses it sent itself are skipped by number too.
  int _armedEpoch = 0;
  final Set<int> _ownPauses = {};

  bool _watchingPort = false;
  List<StreamSubscription<Object?>> _portSubs = const [];
  List<StreamSubscription<Object?>> _clipSubs = const [];

  ValueStream<PreviewClipState> get state => _state.stream;

  /// Plays [provider]'s clip at [url] (http or https only). The song is
  /// paused once the clip has loaded; a clip already playing stops first
  /// and the song stays paused in between.
  Future<PreviewPlayOutcome> play({
    required String provider,
    required Uri url,
  }) async {
    final gen = ++_gen;
    _active = true;
    _stopWatchingClip();
    _publish(PreviewClipState(provider: provider, phase: PreviewPhase.loading));
    if (!_playable(url)) {
      appLog('[preview] the $provider clip has no http(s) address');
      await end(PreviewEnd.failed);
      return PreviewPlayOutcome.failed;
    }
    final clip = _clip ??= _makeClip();
    try {
      await clip.stop();
      if (gen != _gen) return PreviewPlayOutcome.superseded;
      await clip.load(url).timeout(loadTimeout);
    } catch (e) {
      if (gen != _gen) return PreviewPlayOutcome.superseded;
      appLog('[preview] the $provider clip did not load: $e');
      await end(PreviewEnd.failed);
      return PreviewPlayOutcome.failed;
    }
    if (gen != _gen) return PreviewPlayOutcome.superseded;

    // Watching starts before the pause, so no command the user gives while
    // it lands is missed; this flow's own pause is numbered and skipped.
    if (!_watchingPort) _watchPort();
    if (_hold == null && _port.songPlaying) {
      appLog('[preview] pausing the song for a $provider clip');
      final paused = Future.sync(_port.pauseSong);
      final epoch = _port.transportEpoch;
      _ownPauses.add(epoch);
      _hold = (key: _port.songKey, epoch: epoch, target: _port.castTarget);
      _pausing = paused;
      try {
        await paused;
      } catch (e) {
        appLog('[preview] pausing the song failed: $e');
      } finally {
        if (identical(_pausing, paused)) _pausing = null;
      }
      if (gen != _gen) return PreviewPlayOutcome.superseded;
    }
    _publish(PreviewClipState(provider: provider, phase: PreviewPhase.playing));
    _watchClip(clip, gen);
    clip.play();
    return PreviewPlayOutcome.playing;
  }

  /// Ends the flow: the clip stops, and the song resumes when [reason]
  /// allows it and nobody touched the song since the clip paused it.
  /// Safe at any time; with nothing loading or playing it does nothing,
  /// except that [PreviewEnd.sheetClosed] also frees the clip player.
  Future<void> end(PreviewEnd reason) async {
    final clip = _clip;
    final closing = reason == PreviewEnd.sheetClosed;
    if (closing) _clip = null;
    if (!_active) {
      if (closing) {
        _publish(PreviewClipState.idle);
        if (clip != null) await _quietly(clip.dispose);
      }
      return;
    }
    _gen++;
    _active = false;
    _stopWatchingClip();
    _stopWatchingPort();
    final hold = _hold;
    final pauseLanding = _pausing != null;
    _hold = null;
    _pausing = null;
    final provider = _state.value.provider;
    // Started, not awaited, before the song resumes: everything up to the
    // resume runs in this one turn, so no play or end slips in between, and
    // on iOS the song comes back while the session is still active.
    final stopping =
        clip == null ? null : _quietly(closing ? clip.dispose : clip.stop);
    _publish(reason == PreviewEnd.failed
        ? PreviewClipState(provider: provider, phase: PreviewPhase.failed)
        : PreviewClipState.idle);
    if (hold != null) {
      if (resumesSong(
          reason: reason,
          held: hold,
          epochNow: _port.transportEpoch,
          keyNow: _port.songKey,
          targetNow: _port.castTarget,
          songPlaying: !pauseLanding && _port.songPlaying,
          casting: _port.casting)) {
        appLog('[preview] resuming the song (${reason.name})');
        _port.playSong();
      } else {
        appLog('[preview] leaving the song paused (${reason.name})');
      }
    }
    await stopping;
  }

  /// Pure: whether the song a flow paused comes back when the flow ends.
  /// Never once someone else has started it, or after any transport
  /// command, a track change or a cast-target change since the hold.
  static bool resumesSong({
    required PreviewEnd reason,
    required SongHold held,
    required int epochNow,
    required String? keyNow,
    required String targetNow,
    required bool songPlaying,
    required bool casting,
  }) {
    if (songPlaying) return false;
    if (epochNow != held.epoch ||
        keyNow != held.key ||
        targetNow != held.target) {
      return false;
    }
    return switch (reason) {
      PreviewEnd.completed ||
      PreviewEnd.stopped ||
      PreviewEnd.sheetClosed ||
      PreviewEnd.backgrounded ||
      PreviewEnd.failed =>
        true,
      // The handler's own rule: on a cast the audio comes out of the
      // renderer, so the phone's headphones coming out says nothing about
      // it (audio_stuff.dart's becoming-noisy listener).
      PreviewEnd.outputLost => casting,
      PreviewEnd.leftApp ||
      PreviewEnd.interrupted ||
      PreviewEnd.songStarted ||
      PreviewEnd.songTouched =>
        false,
    };
  }

  void _watchPort() {
    _watchingPort = true;
    _armedEpoch = _port.transportEpoch;
    _ownPauses.clear();
    bool? wasPlaying;
    _portSubs = [
      _port.transportCommands.listen(_onCommand, onError: _ignore),
      _port.playingChanges.listen((playing) {
        // Only a false → true edge counts: the first value is a replay,
        // and can still say playing before this flow's pause is broadcast.
        final was = wasPlaying;
        wasPlaying = playing;
        if (was == false && playing) _endSoon(PreviewEnd.songStarted);
      }, onError: _ignore),
      _port.songKeyChanges.listen((key) {
        if (key != _hold?.key) _dropHold('the track changed');
      }, onError: _ignore),
      _port.castTargetChanges.listen((target) {
        if (target != _hold?.target) _dropHold('the cast target changed');
      }, onError: _ignore),
      _port.interruptions.listen((e) {
        // A duck (a notification sound) is the system's to handle.
        if (e.begin && e.type != AudioInterruptionType.duck) {
          _endSoon(PreviewEnd.interrupted);
        }
      }, onError: _ignore),
      _port.becomingNoisy
          .listen((_) => _endSoon(PreviewEnd.outputLost), onError: _ignore),
      _port.appHidden
          .listen((_) => _endSoon(PreviewEnd.backgrounded), onError: _ignore),
    ];
  }

  void _onCommand(TransportCommand c) {
    if (c.epoch <= _armedEpoch || _ownPauses.contains(c.epoch)) return;
    switch (c.command) {
      case 'play':
        _endSoon(PreviewEnd.songStarted);
      case 'pause' || 'stop':
        _endSoon(PreviewEnd.songTouched);
      default:
        // A seek or a skip: the clip plays on, and the song stays paused
        // where the user put it.
        _dropHold(c.command);
    }
  }

  void _watchClip(PreviewClip clip, int gen) {
    void failed(Object e) {
      appLog('[preview] the clip failed while playing: $e');
      _endSoon(PreviewEnd.failed);
    }

    // Each updates the playing state only while this clip is the one
    // playing; an end or a switch cancels them anyway.
    PreviewClipState? playing() {
      final s = _state.value;
      return gen == _gen && s.phase == PreviewPhase.playing ? s : null;
    }

    _clipSubs = [
      clip.position.listen((position) {
        final s = playing();
        if (s == null) return;
        _publish(PreviewClipState(
            provider: s.provider,
            phase: s.phase,
            position: position,
            duration: s.duration));
      }, onError: failed),
      clip.duration.listen((duration) {
        final s = playing();
        if (s == null) return;
        _publish(PreviewClipState(
            provider: s.provider,
            phase: s.phase,
            position: s.position,
            duration: duration));
      }, onError: failed),
      clip.completed
          .listen((_) => _endSoon(PreviewEnd.completed), onError: failed),
      clip.errors.listen(failed, onError: failed),
    ];
  }

  void _dropHold(String why) {
    if (_hold == null) return;
    appLog('[preview] the song stays paused after the clip ($why)');
    _hold = null;
    _pausing = null;
  }

  void _endSoon(PreviewEnd reason) => unawaited(end(reason));

  void _stopWatchingClip() {
    for (final s in _clipSubs) {
      unawaited(s.cancel());
    }
    _clipSubs = const [];
  }

  void _stopWatchingPort() {
    for (final s in _portSubs) {
      unawaited(s.cancel());
    }
    _portSubs = const [];
    _watchingPort = false;
  }

  void _publish(PreviewClipState s) {
    if (_state.value != s) _state.add(s);
  }

  static bool _playable(Uri url) =>
      (url.isScheme('https') || url.isScheme('http')) && url.host.isNotEmpty;

  static void _ignore(Object _) {}

  static Future<void> _quietly(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      appLog('[preview] stopping the clip failed: $e');
    }
  }
}

/// The app's song side. Every member reads its singleton when called, never
/// at construction, and the preview player calls none before a clip loads.
class AppPreviewPort implements PreviewPort {
  AudioPlayerHandler get _handler => MediaManager().audioHandler;

  @override
  bool get songPlaying => _handler.playbackState.valueOrNull?.playing ?? false;

  @override
  String? get songKey =>
      AudioPlayerHandler.trackKey(_handler.mediaItem.valueOrNull);

  @override
  String get castTarget => CastManager().activeTarget.id;

  @override
  bool get casting => CastManager().isCasting;

  @override
  int get transportEpoch => _handler.transport.epoch;

  @override
  Stream<TransportCommand> get transportCommands => _handler.transport.commands;

  @override
  Stream<bool> get playingChanges =>
      _handler.playbackState.map((s) => s.playing).distinct();

  @override
  Stream<String?> get songKeyChanges =>
      _handler.mediaItem.map(AudioPlayerHandler.trackKey).distinct();

  @override
  Stream<String> get castTargetChanges =>
      CastManager().activeTargetStream.map((t) => t.id).distinct();

  @override
  Stream<AudioInterruptionEvent> get interruptions =>
      Stream.fromFuture(AudioSession.instance)
          .asyncExpand((s) => s.interruptionEventStream);

  @override
  Stream<void> get becomingNoisy => Stream.fromFuture(AudioSession.instance)
      .asyncExpand((s) => s.becomingNoisyEventStream);

  // A listener of its own per watch, made when the flow starts watching and
  // disposed when it stops.
  @override
  Stream<void> get appHidden {
    final hidden = StreamController<void>();
    AppLifecycleListener? listener;
    hidden.onListen =
        () => listener = AppLifecycleListener(onHide: () => hidden.add(null));
    hidden.onCancel = () {
      listener?.dispose();
      listener = null;
    };
    return hidden.stream;
  }

  @override
  Future<void> pauseSong() => _handler.pause();

  @override
  void playSong() => unawaited(_handler.play().catchError(
      (Object e) => appLog('[preview] resuming the song failed: $e')));
}

/// The clip on a just_audio player of its own, made on the first load: no
/// tag and no MediaItem (never on the lock screen), and no interruption
/// handling (the preview player decides what an interruption does, and it
/// never brings a clip back). Session activation stays on: the app holds a
/// single audio-focus request, so while the song held focus the clip asks
/// for nothing new. Streamed only, never cached to disk: the stores allow
/// previews to be streamed and nothing more.
class JustAudioPreviewClip implements PreviewClip {
  AudioPlayer? _player;

  AudioPlayer get _p => _player ??= AudioPlayer(handleInterruptions: false);

  @override
  Future<void> load(Uri url) async {
    await _p.setAudioSource(AudioSource.uri(url));
  }

  // just_audio's play completes only when playback next pauses.
  @override
  void play() => unawaited(_p.play().catchError(
      (Object e) => appLog('[preview] the clip would not play: $e')));

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    final p = _player;
    _player = null;
    await p?.dispose();
  }

  @override
  Stream<Duration> get position => _p.positionStream;

  @override
  Stream<Duration?> get duration => _p.durationStream;

  @override
  Stream<void> get completed => _p.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map<void>((_) {});

  @override
  Stream<Object> get errors => _p.errorStream;
}
