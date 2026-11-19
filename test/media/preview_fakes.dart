// Fakes for the preview player and for widget tests that pump a sheet
// playing previews: a song side the test drives (FakePreviewPort, numbered
// by a real TransportLog), a clip whose loads the test settles
// (FakePreviewClip), and FakePreviewPlayer, which stands in for the whole
// player. Port and clip share one call log, so a test can read the order
// "load, pause the song, play the clip".

import 'dart:async';

import 'package:audio_session/audio_session.dart'
    show AudioInterruptionEvent, AudioInterruptionType;
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
  bool playing = false;
  bool disposed = false;

  final BehaviorSubject<bool> _playing = BehaviorSubject<bool>.seeded(false);
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final BehaviorSubject<Duration?> _duration =
      BehaviorSubject<Duration?>.seeded(null);
  final StreamController<void> _completed = StreamController<void>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  int get pendingLoads => _pending.length;

  @override
  Future<void> load(Uri url) {
    log.add('clip.load');
    loads.add(url);
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
    _playing.add(false);
    _interruptLoads();
  }

  @override
  Future<void> dispose() async {
    log.add('clip.dispose');
    disposed = true;
    playing = false;
    _playing.add(false);
    _interruptLoads();
  }

  void emitPosition(Duration p) => _position.add(p);

  void emitDuration(Duration? d) => _duration.add(d);

  /// The clip played to its end.
  void finish() => _completed.add(null);

  /// The clip broke while playing (an expired CDN address, a dropped
  /// connection).
  void breakDown([Object error = 'Source error']) => _errors.add(error);

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<Object> get errors => _errors.stream;
}

/// Stands in for the whole player in widget tests: records each play and
/// end, answers plays with [outcome], and publishes the state the real
/// player would (a test can [emit] any other, e.g. "0:12 of 0:30").
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

  final List<({String provider, Uri url})> plays = [];
  final List<PreviewEnd> ends = [];
  PreviewPlayOutcome outcome = PreviewPlayOutcome.playing;

  /// As the real player's: every end but a clip's own (completed, failed).
  @override
  int endCount = 0;

  @override
  bool appVisible = true;

  @override
  final Duration loadTimeout = const Duration(seconds: 15);

  @override
  ValueStream<PreviewClipState> get state => _state.stream;

  void emit(PreviewClipState s) => _state.add(s);

  @override
  Future<PreviewPlayOutcome> play({
    required String provider,
    required Uri url,
  }) async {
    plays.add((provider: provider, url: url));
    switch (outcome) {
      case PreviewPlayOutcome.playing:
        emit(PreviewClipState(provider: provider, phase: PreviewPhase.playing));
      case PreviewPlayOutcome.failed:
        emit(PreviewClipState(provider: provider, phase: PreviewPhase.failed));
      case PreviewPlayOutcome.superseded:
        break;
    }
    return outcome;
  }

  @override
  Future<void> end(PreviewEnd reason) async {
    ends.add(reason);
    if (reason != PreviewEnd.completed && reason != PreviewEnd.failed) {
      endCount++;
    }
    emit(reason == PreviewEnd.failed
        ? PreviewClipState(
            provider: _state.value.provider, phase: PreviewPhase.failed)
        : PreviewClipState.idle);
  }
}
