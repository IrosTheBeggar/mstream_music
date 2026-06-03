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
  // Android-only native equalizer attached to the player's audio pipeline.
  // just_audio has no iOS/macOS/Linux equivalent, so this stays null on those
  // platforms and the EQ screen renders an "Android only" empty state.
  final AndroidEqualizer? _equalizer =
      Platform.isAndroid ? AndroidEqualizer() : null;

  late final AudioPlayer _player = _equalizer != null
      ? AudioPlayer(
          audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
        )
      : AudioPlayer();

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
  Future<void> setRepeatAll(bool enabled) =>
      _player.setLoopMode(enabled ? LoopMode.all : LoopMode.off);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Synchronous state ──
  @override
  bool get playing => _player.playing;

  @override
  bool get shuffleEnabled => _player.shuffleModeEnabled;

  @override
  bool get repeatAll => _player.loopMode == LoopMode.all;

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

  // ── Local-only capabilities ──
  @override
  bool get supportsEqualizer => _equalizer != null;

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
