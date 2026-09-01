import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'playback_backend.dart';

/// The on-device playback backend: a thin wrapper around a single just_audio
/// [AudioPlayer]. This is the extraction of the behaviour that previously
/// lived directly inside [AudioPlayerHandler] — it must remain behaviourally
/// identical (gapless playlist, native shuffle/repeat, Android equalizer).
class LocalPlaybackBackend implements PlaybackBackend {
  // Android-only native equalizer. Attached to the player's AudioPipeline ONLY
  // when EQ is enabled: an always-attached effect re-activates (priority 0) on
  // every audio-route change (Bluetooth/wired switch), which on Samsung — where
  // SoundAlive/Dolby own the effect chain — can drop the slot and cut playback.
  // So the default is a plain player with nothing in the chain; enabling EQ
  // rebuilds the player WITH the pipeline. Null whenever the plain player is
  // active (and always on non-Android).
  AndroidEqualizer? _equalizer;

  late AudioPlayer _player;

  LocalPlaybackBackend({bool withEqualizer = false}) {
    _buildPlayer(withEqualizer);
  }

  // (Re)construct the underlying just_audio player. just_audio fixes the
  // AudioPipeline at construction and binds an effect instance to a single
  // player, so toggling EQ on/off requires a fresh player (and a fresh
  // AndroidEqualizer for the on case).
  void _buildPlayer(bool withEqualizer) {
    if (withEqualizer && Platform.isAndroid) {
      final eq = AndroidEqualizer();
      _equalizer = eq;
      _player =
          AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq]));
    } else {
      _equalizer = null;
      _player = AudioPlayer();
    }
  }

  /// Swap the underlying player between plain and EQ-pipelined. The new player is
  /// EMPTY: the caller (AudioPlayerHandler) re-seeds the queue, restores
  /// shuffle/repeat, seeks to the saved spot, re-applies EQ gains, and re-emits
  /// the backend so the handler's switchMap re-subscribes to the new player's
  /// streams. The old player is disposed last so the new session id can start
  /// resolving.
  Future<void> rebuildPlayer({required bool withEqualizer}) async {
    final old = _player;
    _buildPlayer(withEqualizer);
    try {
      await old.dispose();
    } catch (_) {
      // The new player is already live; a dispose failure on the orphaned old
      // one must not abort the rebuild (the handler still has to re-seed/re-emit
      // and persist the toggle). Ignore it.
    }
  }

  // ── Source list ──
  // just_audio 0.10 deprecated ConcatenatingAudioSource; the playlist API now
  // lives on AudioPlayer directly.
  @override
  Future<void> setSources(List<MediaItem> items,
          {int? initialIndex, Duration? initialPosition}) =>
      _player.setAudioSources(
          items.map((i) => AudioSource.uri(_uriFor(i))).toList(),
          initialIndex: initialIndex,
          initialPosition: initialPosition);

  @override
  Future<void> addSource(MediaItem item) =>
      _player.addAudioSource(AudioSource.uri(_uriFor(item)));

  @override
  Future<void> addSources(List<MediaItem> items) => _player
      .addAudioSources([for (final i in items) AudioSource.uri(_uriFor(i))]);

  // Play the offline copy when it's actually on disk; otherwise stream
  // (item.id is the server URL). Re-checking existence means a file moved or
  // deleted after the item was built (mid-migration, SD removed) falls back to
  // streaming instead of a broken local URI. Uri.file (not Uri.parse) so
  // user-chosen folder paths with spaces encode correctly. (URI policy moved
  // here from AudioPlayerHandler.addQueueItem; the File.existsSync()/Uri.file
  // hardening came from the server-download-folder PR merged into master.)
  Uri _uriFor(MediaItem item) {
    final localPath = item.extras?['localPath'];
    return (localPath != null && File(localPath).existsSync())
        ? Uri.file(localPath)
        : Uri.parse(item.id);
  }

  @override
  Future<void> removeSourceAt(int index) => _player.removeAudioSourceAt(index);

  @override
  Future<void> moveSource(int from, int to) =>
      _player.moveAudioSource(from, to);

  @override
  Future<void> clearSources() => _player.clearAudioSources();

  // ── Transport ──
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position, {int? index, bool? play}) async {
    await _player.seek(position, index: index);
    // just_audio's play() future completes only when playback pauses/stops, so
    // it must NOT be awaited in the switch path (that previously blocked the
    // backend switch). Fire it and move on.
    if (play == true) {
      unawaited(_player.play());
    } else if (play == false) {
      await _player.pause();
    }
  }

  @override
  Future<void> seekToNext() => _player.seekToNext();

  @override
  Future<void> seekToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setShuffleEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  @override
  Future<void> setRepeat(BackendRepeat mode) =>
      _player.setLoopMode(switch (mode) {
        BackendRepeat.off => LoopMode.off,
        BackendRepeat.all => LoopMode.all,
        BackendRepeat.one => LoopMode.one,
      });

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Synchronous state ──
  @override
  bool get playing => _player.playing;

  @override
  bool get shuffleEnabled => _player.shuffleModeEnabled;

  @override
  BackendRepeat get repeat => switch (_player.loopMode) {
        LoopMode.off => BackendRepeat.off,
        LoopMode.all => BackendRepeat.all,
        LoopMode.one => BackendRepeat.one,
      };

  // ── Duration-less streams ──
  // A chunked, length-less stream (the iOS /transcode fallback's transport)
  // has no knowable duration, but it reaches Dart as Duration.ZERO, not null
  // (AVPlayer reports "indefinite"; the bridge lands it as 0). Zero then
  // defeats every null-means-unknown guard downstream: just_audio's position
  // getter clamps its extrapolated position to any non-null duration — so the
  // whole track "plays at 00:00" — and the handler stamps "/ 00:00" into the
  // MediaItem. Normalize zero to null at this boundary and, while the player
  // claims a zero duration, compute the position with just_audio's own
  // extrapolation formula minus the clamp. A genuinely zero-length file has
  // no audio to position through, so treating it as unknown loses nothing.

  bool get _durationUnknown => _player.duration == Duration.zero;

  Duration _unclampedPosition(DateTime now) => unclampedPositionFor(
      updatePosition: _player.playbackEvent.updatePosition,
      updateTime: _player.playbackEvent.updateTime,
      now: now,
      speed: _player.speed,
      extrapolating:
          _player.playing && _player.processingState == ProcessingState.ready);

  /// Duration.zero means "unknown", never "instant" — see the note above.
  /// Pure; unit-tested.
  static Duration? normalizeReportedDuration(Duration? d) =>
      d == Duration.zero ? null : d;

  /// just_audio's position extrapolation without its clamp-to-duration:
  /// while playing-and-ready the position advances from the last platform
  /// event in wall-clock time (scaled by [speed]); otherwise it holds at the
  /// event's position. Pure; unit-tested.
  static Duration unclampedPositionFor({
    required Duration updatePosition,
    required DateTime updateTime,
    required DateTime now,
    required double speed,
    required bool extrapolating,
  }) =>
      extrapolating
          ? updatePosition + now.difference(updateTime) * speed
          : updatePosition;

  @override
  Duration get position =>
      _durationUnknown ? _unclampedPosition(DateTime.now()) : _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  double get speed => _player.speed;

  @override
  Duration? get duration => normalizeReportedDuration(_player.duration);

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  BackendProcessingState get processingState =>
      _mapState(_player.processingState);

  // ── Streams ──
  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  // just_audio's stream carries its clamped position — for a zero-duration
  // stream that is a constant 0 (see the duration-less note above) — so while
  // the duration reads zero, tick the unclamped reading ourselves at
  // just_audio's slowest own cadence. durationStream replays its current
  // value on listen, so each subscriber starts on the right branch, and a
  // track change flips the branch via switchMap.
  @override
  Stream<Duration> get positionStream =>
      _player.durationStream.switchMap((d) => d == Duration.zero
          ? Stream<Duration>.periodic(const Duration(milliseconds: 200),
              (_) => _unclampedPosition(DateTime.now()))
          : _player.positionStream);

  @override
  Stream<Duration?> get durationStream =>
      _player.durationStream.map(normalizeReportedDuration);

  @override
  Stream<BackendProcessingState> get processingStateStream =>
      _player.processingStateStream.map(_mapState);

  @override
  Stream<void> get changeStream => _player.playbackEventStream.map<void>((_) {});

  // On-device playback never "loses a renderer", so this never emits.
  @override
  Stream<String> get rendererLostStream => const Stream<String>.empty();

  // just_audio routes playback failures (a source dying mid-stream) to its
  // dedicated errorStream as PlayerException values — NOT as errors on
  // playbackEventStream — so this is the channel the handler must watch.
  @override
  Stream<Object> get errorStream => _player.errorStream;

  // ── Local-only capabilities ──
  // Stable capability: Android local playback can host the native EQ regardless
  // of whether the pipeline is currently attached. `equalizer` is null while EQ
  // is off (plain player); enabling EQ rebuilds the player with the pipeline.
  @override
  bool get supportsEqualizer => Platform.isAndroid;

  @override
  AndroidEqualizer? get equalizer => _equalizer;

  @override
  int? get androidAudioSessionId => _player.androidAudioSessionId;

  @override
  Future<void> dispose() => _player.dispose();

  static BackendProcessingState _mapState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return BackendProcessingState.idle;
      case ProcessingState.loading:
        return BackendProcessingState.loading;
      case ProcessingState.buffering:
        return BackendProcessingState.buffering;
      case ProcessingState.ready:
        return BackendProcessingState.ready;
      case ProcessingState.completed:
        return BackendProcessingState.completed;
    }
  }
}
