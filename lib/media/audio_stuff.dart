import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  int? get index => _player.currentIndex;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // AudioSession.instance.then((session) {
    //   session.configure(const AudioSessionConfiguration.music());
    // });
    // final session = await AudioSession.instance;

    //     // Handle unplugged headphones.
    // session.becomingNoisyEventStream.listen((_) {
    //   if (_playing) pause();
    // });

    // For Android 11, record the most recent item so it can be resumed.
    mediaItem
        .whereType<MediaItem>()
        .listen((item) => _recentSubject.add([item]));
    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value!.isNotEmpty)
        mediaItem.add(queue.value![index]);
    });
    // Magic
    _player.durationStream.listen((duration) {
      if (index != null && duration != null) {
        mediaItem
            .add(queue.value![index!.toInt()].copyWith(duration: duration));
      }
    });
    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);
    // In this example, the service stops when reaching the end.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
    });
    try {
      print("### _player.load");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!
      //await Future.delayed(Duration(seconds: 2)); // magic delay
      queue.value!.forEach((element) {
        _playlist.add(AudioSource.uri(Uri.parse(element.id)));
      });

      await _player.setAudioSource(_playlist);
      // TODO: We might need this later
      // await _player.setAudioSource(ConcatenatingAudioSource(
      //   children: queue.value!
      //       .map((item) => AudioSource.uri(Uri.parse(item.id)))
      //       .toList(),
      // ));
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index > queue.value!.length) return;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: index);
    // Demonstrate custom events.
    customEvent.add('skip to $index');
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    queue.add(queue.value!..add(item));
    _playlist.add(AudioSource.uri(Uri.parse(item.id)));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> skipToNext() async {
    _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _player.seekToPrevious();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode doesntMatter) async {
    if (_player.shuffleModeEnabled == true) {
      _player.setShuffleModeEnabled(false);
      await super.setShuffleMode(AudioServiceShuffleMode.none);
    } else {
      _player.setShuffleModeEnabled(true);
      await super.setShuffleMode(AudioServiceShuffleMode.all);
    }

    // TODO: Is this correct?
    _broadcastState(new PlaybackEvent());
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode doesntMatter) async {
    if (_player.loopMode == LoopMode.all) {
      _player.setLoopMode(LoopMode.off);
      await super.setRepeatMode(AudioServiceRepeatMode.none);
    } else {
      _player.setLoopMode(LoopMode.all);
      await super.setRepeatMode(AudioServiceRepeatMode.all);
    }

    // TODO: Is this correct?
    _broadcastState(new PlaybackEvent());
  }

  @override
  Future<void> removeQueueItem(MediaItem i) async {
    await super.removeQueueItem(i);
    // TODO: See removeQueueItemAt
  }

  @override
  Future<void> removeQueueItemAt(int i) async {
    await super.removeQueueItemAt(i);
    queue.add(queue.value!..removeAt(i));
    _playlist.removeAt(i);
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final AudioServiceShuffleMode shuffle = _player.shuffleModeEnabled == true
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;

    final AudioServiceRepeatMode repeat = _player.loopMode == LoopMode.all
        ? AudioServiceRepeatMode.all
        : AudioServiceRepeatMode.none;

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
      },
      shuffleMode: shuffle,
      repeatMode: repeat,
      androidCompactActionIndices: [0, 1, 3],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
