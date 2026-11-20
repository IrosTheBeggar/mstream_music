// Fakes for the preview player and for widget tests that pump a sheet
// playing previews: a song side the test drives (FakePreviewPort, numbered
// by a real TransportLog), a clip whose loads the test settles
// (FakePreviewClip), and FakePreviewPlayer, which stands in for the whole
// player. Port and clip share one call log, so a test can read the order
// "load, pause the song, play the clip".

import 'dart:async';

import 'package:audio_session/audio_session.dart'
    show AudioInterruptionEvent, AudioInterruptionType;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/cast_target.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/media/transport_log.dart';
import 'package:rxdart/rxdart.dart';

const String kFakeSongKey = 'home\u0000/Music/Tidewater.mp3';

class FakePreviewPort implements PreviewPort {
  FakePreviewPort({
    bool songPlaying = true,
    String? songKey = kFakeSongKey,
    String castTarget = CastTarget.localId,
    this.casting = false,
    List<String>? log,
  })  : log = log ?? [],
        _playing = BehaviorSubject<bool>.seeded(songPlaying),
        _key = BehaviorSubject<String?>.seeded(songKey),
        _target = BehaviorSubject<String>.seeded(castTarget);

  final List<String> log;
  final TransportLog transport = TransportLog();
  final BehaviorSubject<bool> _playing;
  final BehaviorSubject<String?> _key;
  final BehaviorSubject<String> _target;
  final StreamController<AudioInterruptionEvent> _interruptions =
      StreamController<AudioInterruptionEvent>.broadcast();
  final StreamController<void> _noisy = StreamController<void>.broadcast();
  final StreamController<void> _hidden = StreamController<void>.broadcast();

  @override
  bool casting;

  /// The app is in front ([hideApp] clears it, [showApp] sets it again).
  bool visible = true;

  /// Every read or call of the song's side (the handler, the cast manager)
  /// the preview player made.
  int touches = 0;

  /// Every read of the world around it (the session, the app's lifecycle).
  int outsideTouches = 0;

  /// The preview player's own pause and play of the song.
  int pauses = 0;
  int plays = 0;

  /// While set, the song's playing flag drops only once this completes (a
  /// cast renderer answering slowly). The pause is numbered at once.
  Completer<void>? pauseGate;

  /// Runs once a pause of the preview player's has dropped the song's
  /// flag, before that pause returns: a cast renderer's poll still
  /// answering PLAYING just after it (startsByItself).
  void Function()? onPauseLanded;

  bool get playingNow => _playing.value;

  /// How many are listening to the song side (0 once a flow has ended).
  int get listeners =>
      (_playing.hasListener ? 1 : 0) +
      (_key.hasListener ? 1 : 0) +
      (_target.hasListener ? 1 : 0) +
      (_interruptions.hasListener ? 1 : 0) +
      (_noisy.hasListener ? 1 : 0) +
      (_hidden.hasListener ? 1 : 0);

  T _touch<T>(T value) {
    touches++;
    return value;
  }

  T _outside<T>(T value) {
    outsideTouches++;
    return value;
  }

  @override
  bool get songPlaying => _touch(_playing.value);

  @override
  String? get songKey => _touch(_key.value);

  @override
  String get castTarget => _touch(_target.value);

  @override
  int get transportEpoch => _touch(transport.epoch);

  @override
  Stream<TransportCommand> get transportCommands => _touch(transport.commands);

  @override
  Stream<bool> get playingChanges => _touch(_playing.stream.distinct());

  @override
  Stream<String?> get songKeyChanges => _touch(_key.stream.distinct());

  @override
  Stream<String> get castTargetChanges => _touch(_target.stream.distinct());

  @override
  Stream<AudioInterruptionEvent> get interruptions =>
      _outside(_interruptions.stream);

  @override
  Stream<void> get becomingNoisy => _outside(_noisy.stream);

  @override
  Stream<void> get appHidden => _outside(_hidden.stream);

  @override
  bool get appVisible => _outside(visible);

  @override
  Future<void> pauseSong() async {
    touches++;
    pauses++;
    log.add('song.pause');
    transport.note('pause');
    final gate = pauseGate;
    if (gate != null) await gate.future;
    _playing.add(false);
    onPauseLanded?.call();
  }

  @override
  void playSong() {
    touches++;
    plays++;
    log.add('song.play');
    transport.note('play');
    _playing.add(true);
  }

  // ── what the user, the system and the handler do ─────────────────────

  /// Play on the lock screen, CarPlay, a headset or the mini player.
  void userPlay() {
    transport.note('play');
    _playing.add(true);
  }

  /// The sleep timer, Siri or Assistant: a pause that may change nothing.
  void userPause() {
    transport.note('pause');
    _playing.add(false);
  }

  void userStop() {
    transport.note('stop');
    _playing.add(false);
  }

  void userCommand(String verb) => transport.note(verb);

  /// The song starting with no command (a park pick landing, a resume
  /// after a call).
  void startsByItself() => _playing.add(true);

  /// The song's flag dropping with no command (a cast renderer's poll
  /// answering PAUSED after a stale PLAYING).
  void pausedByItself() => _playing.add(false);

  void changeTrack(String? key) => _key.add(key);

  void changeCastTarget(String id, {bool casting = true}) {
    this.casting = casting;
    _target.add(id);
  }

  void interrupt([AudioInterruptionType type = AudioInterruptionType.pause]) =>
      _interruptions.add(AudioInterruptionEvent(true, type));

  void interruptionEnds() => _interruptions
      .add(AudioInterruptionEvent(false, AudioInterruptionType.pause));

  void becomeNoisy() => _noisy.add(null);

  void hideApp() {
    visible = false;
    _hidden.add(null);
  }

  void showApp() => visible = true;
}

/// FakePreviewPort with the app's own lifecycle side: [appHidden] is the
/// app port's (an AppLifecycleListener per watch) and [appVisible] reads
/// the binding, so a widget test drives both through
/// `tester.binding.handleAppLifecycleStateChanged` ([hideApp] and
/// [showApp] reach neither).
class BindingPreviewPort extends FakePreviewPort {
  BindingPreviewPort({super.songPlaying, super.log});

  final AppPreviewPort _app = AppPreviewPort();

  @override
  Stream<void> get appHidden => _app.appHidden;

  @override
  bool get appVisible => _app.appVisible;
}

/// The app sent to the background as iOS reports it: the services binding
/// turns one "paused" into inactive, hidden and paused, told to every
/// binding observer in one go (no microtask in between).
void backgroundApp(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// Back in front: hidden, inactive and resumed, in one go.
void foregroundApp(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

class FakePreviewClip implements PreviewClip {
  FakePreviewClip({List<String>? log}) : log = log ?? [];

  final List<String> log;
  final List<Uri> loads = [];

  /// Loads wait for [finishLoad] / [failLoad] instead of landing at once.
  bool holdLoads = false;

  /// The next load fails with this.
  Object? loadError;

  /// The next play fails with this (iOS: the session would not activate).
  Object? playError;

  final List<Completer<void>> _pending = [];
  int playCalls = 0;
  int stopCalls = 0;

  /// Every pause the preview player asked of the clip.
  int pauses = 0;
  bool playing = false;
  bool disposed = false;

  final BehaviorSubject<bool> _playing = BehaviorSubject<bool>.seeded(false);
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final BehaviorSubject<Duration?> _duration =
      BehaviorSubject<Duration?>.seeded(null);
  final StreamController<void> _completed = StreamController<void>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  /// At its end since [finish], until the next load or stop: a completed
  /// listener that comes then is told at once (PreviewClip.completed).
  bool atEnd = false;

  int get pendingLoads => _pending.length;

  @override
  Future<void> load(Uri url) {
    log.add('clip.load');
    loads.add(url);
    atEnd = false;
    final error = loadError;
    if (error != null) {
      loadError = null;
      return Future<void>.error(error);
    }
    if (!holdLoads) return Future<void>.value();
    final c = Completer<void>();
    _pending.add(c);
    return c.future;
  }

  void finishLoad() => _pending.removeAt(0).complete();

  void failLoad(Object error) => _pending.removeAt(0).completeError(error);

  @override
  Future<void> play() {
    log.add('clip.play');
    playCalls++;
    playing = true;
    _playing.add(true);
    final error = playError;
    if (error != null) {
      playError = null;
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }

  // As just_audio's: the playing flag goes off at once, the position stays.
  @override
  Future<void> pause() async {
    log.add('clip.pause');
    pauses++;
    playing = false;
    _playing.add(false);
  }

  /// The system refused the audio with no error, as just_audio does when
  /// Android's focus request fails: the playing flag goes back off.
  void refuse() {
    playing = false;
    _playing.add(false);
  }

  // As just_audio's: a stop interrupts a load still in flight.
  void _interruptLoads() {
    for (final c in _pending) {
      c.completeError(StateError('Loading interrupted'));
    }
    _pending.clear();
  }

  @override
  Future<void> stop() async {
    log.add('clip.stop');
    stopCalls++;
    playing = false;
    atEnd = false;
    _playing.add(false);
    _interruptLoads();
  }

  @override
  Future<void> dispose() async {
    log.add('clip.dispose');
    disposed = true;
    playing = false;
    atEnd = false;
    _playing.add(false);
    _interruptLoads();
  }

  void emitPosition(Duration p) => _position.add(p);

  void emitDuration(Duration? d) => _duration.add(d);

  /// The clip played to its end.
  void finish() {
    atEnd = true;
    _completed.add(null);
  }

  /// The clip broke while playing (an expired CDN address, a dropped
  /// connection).
  void breakDown([Object error = 'Source error']) => _errors.add(error);

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  // As just_audio's processing state, which replays to a new listener.
  @override
  Stream<void> get completed =>
      atEnd ? _completed.stream.startWith(null) : _completed.stream;

  @override
  Stream<Object> get errors => _errors.stream;
}

/// Stands in for the whole player in widget tests: records each play and
/// end, answers plays with [outcome], and publishes the state the real
/// player would (a test can [emit] any other, e.g. "0:12 of 0:30").
///
/// Whether a flow runs, and whose it is, is read from the state alone —
/// a flow runs while it is loading, playing, paused or held, and its owner
/// is the state's — never from what [play] was told: a state a test emits
/// (a page's clip, `owner: Object()`) counts exactly like one a play
/// published. The owner rules are the real player's: a null owner on
/// either side matches. It has no load phase (a play answers at once);
/// tests that need a load in flight or a real hold use the real player
/// over [FakePreviewPort] and [FakePreviewClip]. A failed play's state
/// reaches listeners here before the play returns; the real player's can
/// reach them after, so a test of that order uses the real player too.
///
///     late FakePreviewPlayer preview;
///     setUp(() => preview = FakePreviewPlayer.install());
class FakePreviewPlayer implements PreviewPlayer {
  /// Puts a fresh fake in PreviewPlayer.instance for the current test and
  /// puts the previous player back when it ends.
  static FakePreviewPlayer install() {
    final previous = PreviewPlayer.instance;
    final fake = FakePreviewPlayer();
    PreviewPlayer.instance = fake;
    addTearDown(() => PreviewPlayer.instance = previous);
    return fake;
  }

  final BehaviorSubject<PreviewClipState> _state =
      BehaviorSubject<PreviewClipState>.seeded(PreviewClipState.idle);

  final List<({String provider, Uri url, Object? owner, bool holdOnComplete})>
  plays = [];

  /// The ends that ran (another owner's, ignored, are left out).
  final List<PreviewEnd> ends = [];

  /// Every end asked for, with the owner it named, ignored or not.
  final List<({PreviewEnd reason, Object? owner})> endCalls = [];

  /// The pauses, resumes and keepHelds the player took (refused ones are
  /// not counted).
  int pauses = 0;
  int resumes = 0;
  int keepHelds = 0;
  PreviewPlayOutcome outcome = PreviewPlayOutcome.playing;

  /// The song a playing clip paused, as the real player would hold it (a
  /// play that plays holds [kFakeHold]; every end lets go of it).
  SongHold? held;

  /// The holds handed back to [resumeHeld] (a link that did not open).
  final List<SongHold> resumed = [];

  static const SongHold kFakeHold =
      (key: kFakeSongKey, epoch: 1, target: CastTarget.localId);

  /// As the real player's: every end but a clip's own (completed, failed);
  /// one that names its owner only when it ends a flow.
  @override
  int endCount = 0;

  @override
  bool appVisible = true;

  /// The song is playing (as FakePreviewPort's, playing by default).
  @override
  bool songPlaying = true;

  final StreamController<void> _songStarts = StreamController<void>.broadcast();

  @override
  Stream<void> get songStarts => _songStarts.stream;

  /// Someone listens for the song starting.
  bool get watchingSong => _songStarts.hasListener;

  /// The user started the song (Play on the mini player, the lock screen).
  void startSong() {
    songPlaying = true;
    _songStarts.add(null);
  }

  /// The owners that took a flow over ([claim] answered true).
  final List<Object> claims = [];

  @override
  final Duration loadTimeout = const Duration(seconds: 15);

  @override
  final Duration heldTimeout = const Duration(seconds: 120);

  // What the last play asked of its clip's completion ([complete]).
  bool _holdOnComplete = false;

  @override
  ValueStream<PreviewClipState> get state => _state.stream;

  /// As the real player's: the song is watched once a clip of the flow has
  /// loaded (a state playing or paused since the flow began), until the
  /// flow ends. A flow held or loading before any clip played is not.
  @override
  bool get flowWatchesSong => _clipLoaded;
  bool _clipLoaded = false;

  void emit(PreviewClipState s) {
    switch (s.phase) {
      case PreviewPhase.playing || PreviewPhase.paused:
        _clipLoaded = true;
      case PreviewPhase.idle || PreviewPhase.failed:
        _clipLoaded = false;
      case PreviewPhase.loading || PreviewPhase.held:
        break;
    }
    _state.add(s);
  }

  /// A flow runs: the state is loading, playing, paused or held.
  bool get active => switch (_state.value.phase) {
    PreviewPhase.loading ||
    PreviewPhase.playing ||
    PreviewPhase.paused ||
    PreviewPhase.held => true,
    PreviewPhase.idle || PreviewPhase.failed => false,
  };

  /// As the real player's: no flow runs, either side named nobody, or it
  /// is the state's owner.
  bool _ownedBy(Object? owner) {
    final now = _state.value.owner;
    return owner == null || !active || now == null || identical(now, owner);
  }

  @override
  Future<PreviewPlayOutcome> play({
    required String provider,
    required Uri url,
    Object? owner,
    bool holdOnComplete = false,
  }) async {
    plays.add((
      provider: provider,
      url: url,
      owner: owner,
      holdOnComplete: holdOnComplete,
    ));
    _holdOnComplete = holdOnComplete;
    switch (outcome) {
      case PreviewPlayOutcome.playing:
        held ??= kFakeHold;
        emit(PreviewClipState(
            provider: provider, phase: PreviewPhase.playing, owner: owner));
      case PreviewPlayOutcome.failed:
        emit(PreviewClipState(
            provider: provider, phase: PreviewPhase.failed, owner: owner));
      case PreviewPlayOutcome.superseded:
        break;
    }
    return outcome;
  }

  @override
  Future<void> end(PreviewEnd reason, {Object? owner}) async {
    endCalls.add((reason: reason, owner: owner));
    if (!_ownedBy(owner)) return;
    final s = _state.value;
    final wasActive = active;
    ends.add(reason);
    held = null;
    _holdOnComplete = false;
    if (reason != PreviewEnd.completed &&
        reason != PreviewEnd.failed &&
        (owner == null || wasActive)) {
      endCount++;
    }
    emit(reason == PreviewEnd.failed
        ? PreviewClipState(
            provider: s.provider, phase: PreviewPhase.failed, owner: s.owner)
        : PreviewClipState.idle);
  }

  @override
  Future<bool> pause({Object? owner}) async {
    final s = _state.value;
    if (!active || !_ownedBy(owner) || s.phase != PreviewPhase.playing) {
      return false;
    }
    pauses++;
    emit(PreviewClipState(
        provider: s.provider,
        phase: PreviewPhase.paused,
        position: s.position,
        duration: s.duration,
        owner: s.owner));
    return true;
  }

  @override
  Future<bool> resume({Object? owner}) async {
    final s = _state.value;
    if (!active ||
        !_ownedBy(owner) ||
        s.phase != PreviewPhase.paused ||
        !appVisible) {
      return false;
    }
    resumes++;
    emit(PreviewClipState(
        provider: s.provider,
        phase: PreviewPhase.playing,
        position: s.position,
        duration: s.duration,
        owner: s.owner));
    return true;
  }

  @override
  void keepHeld({Object? owner}) {
    if (!active ||
        !_ownedBy(owner) ||
        _state.value.phase != PreviewPhase.held) {
      return;
    }
    keepHelds++;
  }

  /// As the real player's: a running flow becomes [owner]'s, held, its
  /// provider kept; false with no flow.
  @override
  bool claim({required Object owner}) {
    final s = _state.value;
    if (!active) return false;
    if (identical(s.owner, owner)) return true;
    claims.add(owner);
    _holdOnComplete = false;
    emit(PreviewClipState(
        provider: s.provider, phase: PreviewPhase.held, owner: owner));
    return true;
  }

  /// The clip played to its end: held (the state's owner kept) when the
  /// last play asked to hold on completion, else the flow ends as
  /// completed.
  Future<void> complete() async {
    final s = _state.value;
    if (_holdOnComplete && active) {
      emit(PreviewClipState(
          provider: s.provider, phase: PreviewPhase.held, owner: s.owner));
      return;
    }
    await end(PreviewEnd.completed);
  }

  @override
  SongHold? endLeavingApp() {
    final hold = held;
    unawaited(end(PreviewEnd.leftApp));
    return hold;
  }

  @override
  void resumeHeld(SongHold hold) => resumed.add(hold);
}
