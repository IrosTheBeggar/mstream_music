import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart';

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
    await old.dispose();
  }

  // ── Source list ──
  // just_audio 0.10 deprecated ConcatenatingAudioSource; the playlist API now
  // lives on AudioPlayer directly.
  @override
  Future<void> setSources(List<MediaItem> items) => _player.setAudioSources(
      items.map((i) => AudioSource.uri(_uriFor(i))).toList());

  @override
  Future<void> addSource(MediaItem item) =>
      _player.addAudioSource(AudioSource.uri(_uriFor(item)));

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

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  double get speed => _player.speed;

  @override
  Duration? get duration => _player.duration;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  BackendProcessingState get processingState =>
      _mapState(_player.processingState);

  // ── Streams ──
  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

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
