import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:mstream_music/main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  int? get index => _player.currentIndex;

  String? autoDJServer;
  String? autoDJToken;
  var jsonAutoDJIgnoreList;

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
      print(index);
      print(queue.value.length);

      if (index == queue.value.length - 1) {
        autoDJ();
      }

      if (index != null && queue.value.isNotEmpty)
        mediaItem.add(queue.value[index]);
    });
    // Magic
    _player.durationStream.listen((duration) {
      if (index != null && duration != null) {
        mediaItem.add(queue.value[index!.toInt()].copyWith(duration: duration));
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
      queue.value.forEach((element) {
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
  BehaviorSubject<dynamic> customState =
      BehaviorSubject<dynamic>.seeded(CustomEvent(null));

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index > queue.value.length) return;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: index);
    // Demonstrate custom events.
    customEvent.add('skip to $index');
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    queue.add(queue.value..add(item));

    if (item.extras?['localPath'] != null) {
      _playlist.add(AudioSource.uri(Uri.parse(item.extras!['localPath'])));
    } else {
      _playlist.add(AudioSource.uri(Uri.parse(item.id)));
    }
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
    await _playlist.removeAt(i);
    queue.add(queue.value..removeAt(i));
  }

  customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'clearPlaylist':
        await _player.stop();
        await super.stop();
        await _playlist.clear();
        queue.add(queue.value..clear());
        _broadcastState(new PlaybackEvent());
        break;
      case 'setAutoDJ':
        if (autoDJServer == extras?['serverURL']) {
          //  NOTE: This logic might be moved to the frontend
          autoDJServer = null;
          autoDJToken = null;
          jsonAutoDJIgnoreList = null;
          customState.add(CustomEvent(autoDJServer));

          return;
        }

        autoDJServer = extras?['serverURL'];
        autoDJToken = extras?['token'];
        jsonAutoDJIgnoreList = null;

        if (queue.value.length == 0 ||
            queue.value.length == 1 ||
            index == queue.value.length - 1) {
          if (queue.value.length == 0) {
            await autoDJ(autoPlay: true);
            autoDJ();
          } else if (index == queue.value.length - 1 &&
              _player.processingState == ProcessingState.idle) {
            autoDJ(autoPlay: true, incrementIndex: true);
          } else {
            autoDJ();
          }
        }

        customState.add(CustomEvent(autoDJServer));
        break;
    }
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

  Future<void> autoDJ(
      {bool autoPlay = false, bool incrementIndex = false}) async {
    if (autoDJServer == null) {
      return;
    }

    try {
      Uri currentUri =
          Uri.parse(autoDJServer!).resolve('/api/v1/db/random-songs');

      String payload = '{"ignoreList":${json.encode(jsonAutoDJIgnoreList)}}';

      var res = await http.post(currentUri,
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': autoDJToken ?? ''
          },
          body: payload);

      var decoded = jsonDecode(res.body);

      String p = '';
      decoded['songs'][0]['filepath'].split("/").forEach((element) {
        if (element.length == 0) {
          return;
        }
        p += "/" + Uri.encodeComponent(element);
      });

      String lolUrl = autoDJServer! +
          '/media' +
          p +
          '?app_uuid=' +
          Uuid().v4() +
          (autoDJToken == null ? '' : '&token=' + autoDJToken!);

      MediaItem item = new MediaItem(
          id: lolUrl,
          title: decoded['songs'][0]['filepath'].split("/").removeLast(),
          extras: {'path': decoded['songs'][0]['filepath']});

      jsonAutoDJIgnoreList = decoded['ignoreList'];

      addQueueItem(item);

      if (incrementIndex == true) {
        _player.seek(Duration.zero, index: index! + 1);
      }
      if (autoPlay == true) {
        play();
      }
    } catch (err) {}
  }
}
