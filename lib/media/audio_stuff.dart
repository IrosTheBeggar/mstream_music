import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mstream_music/main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../objects/server.dart';
import '../singletons/settings.dart';

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  // Android-only: a native equalizer attached to the player's audio
  // pipeline. just_audio has no iOS/macOS/Linux equivalent, so this
  // stays null on those platforms and the EQ screen renders an
  // "Android only" empty state instead.
  final AndroidEqualizer? equalizer =
      Platform.isAndroid ? AndroidEqualizer() : null;
  late final AudioPlayer _player = equalizer != null
      ? AudioPlayer(
          audioPipeline:
              AudioPipeline(androidAudioEffects: [equalizer!]),
        )
      : AudioPlayer();

  int? get index => _player.currentIndex;

  Stream<Duration> get positionStream => _player.positionStream;

  Server? autoDJServer;

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
    // Broadcast media item changes (with duration if it's known yet).
    _player.currentIndexStream.listen((index) {
      if (index == queue.value.length - 1) {
        autoDJ();
      }
      _emitCurrentMediaItem();
    });
    // duration usually arrives via durationStream after the source
    // loads. Re-emit the current MediaItem with the duration filled in
    // so the BottomBar progress formula stops dividing by 1.
    _player.durationStream.listen((_) => _emitCurrentMediaItem());
    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);
    // In this example, the service stops when reaching the end.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
    });
    try {
      print("### _player.setAudioSources (init)");
      // just_audio 0.10 deprecated ConcatenatingAudioSource; the playlist
      // API now lives on AudioPlayer directly. Seed with whatever is
      // already in the queue (typically empty on cold start).
      await _player.setAudioSources(
        queue.value
            .map((item) => AudioSource.uri(Uri.parse(item.id)))
            .toList(),
      );
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }
    await _applySavedEqualizer();
  }

  // Apply persisted EQ state to the native equalizer. Best-effort: if
  // the saved gains array is shorter than the device's actual band
  // count, leftover bands are left at device default. Wrapped in
  // try/catch so a flaky audio session never blocks player init.
  Future<void> _applySavedEqualizer() async {
    final eq = equalizer;
    if (eq == null) return;
    try {
      await eq.setEnabled(SettingsManager().eqEnabled);
      final saved = SettingsManager().eqBandGains;
      if (saved.isEmpty) return;
      final params = await eq.parameters;
      for (var i = 0; i < params.bands.length && i < saved.length; i++) {
        await params.bands[i].setGain(saved[i]);
      }
    } catch (e) {
      print("EQ apply error: $e");
    }
  }

  void _emitCurrentMediaItem() {
    if (queue.value.isEmpty) return;
    final i = (index ?? 0).clamp(0, queue.value.length - 1);
    final item = queue.value[i];
    final dur = _player.duration;
    mediaItem.add(dur != null ? item.copyWith(duration: dur) : item);
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
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    queue.add(queue.value..add(item));

    final uri = item.extras?['localPath'] != null
        ? Uri.parse(item.extras!['localPath'])
        : Uri.parse(item.id);
    await _player.addAudioSource(AudioSource.uri(uri));
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
    await _player.removeAudioSourceAt(i);
    queue.add(queue.value..removeAt(i));
  }

  customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'clearPlaylist':
        await _player.stop();
        await super.stop();
        await _player.clearAudioSources();
        queue.add(queue.value..clear());
        _broadcastState(new PlaybackEvent());
        break;
      case 'forceAutoDJRefresh':
        customState.add(CustomEvent(autoDJServer));
        break;
      case 'setAutoDJ':
        if (autoDJServer == null || autoDJServer != extras?['autoDJServer']) {
          jsonAutoDJIgnoreList = null;
        }
        autoDJServer = extras?['autoDJServer'];

        customState.add(CustomEvent(autoDJServer));

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
      Uri currentUri = Uri.parse(autoDJServer!.url.toString())
          .resolve('/api/v1/db/random-songs');

      bool flagIt = false;
      String ignoreVPathString = '[';
      autoDJServer?.autoDJPaths.forEach((key, value) {
        if (value == false) {
          ignoreVPathString += '${flagIt == false ? '' : ','} "$key"';
          flagIt = true;
        }
      });
      ignoreVPathString += '],';

      print(ignoreVPathString);

      String payload = '''{"minRating":${autoDJServer?.autoDJminRating},
          ${flagIt == true ? '"ignoreVPaths": $ignoreVPathString' : ''}
          "ignoreList":${json.encode(jsonAutoDJIgnoreList)}}''';

      var res = await http.post(currentUri,
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': autoDJServer?.jwt ?? ''
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

      String lolUrl = autoDJServer!.url.toString() +
          '/media' +
          p +
          '?app_uuid=' +
          Uuid().v4() +
          (autoDJServer?.jwt == null ? '' : '&token=' + autoDJServer!.jwt!);

      String? artUrl = decoded['songs'][0]['metadata']['album-art'] != null
          ? Uri.parse(autoDJServer!.url.toString())
              .resolve('/album-art/' +
                  decoded['songs'][0]['metadata']['album-art'] +
                  '?compress=l&token=' +
                  (autoDJServer?.jwt ?? ''))
              .toString()
          : null;

      MediaItem item = new MediaItem(
          id: lolUrl,
          title: decoded['songs'][0]['metadata']['title'] ??
              decoded['songs'][0]['filepath'].split("/").removeLast(),
          album: decoded['songs'][0]['metadata']['album'],
          artist: decoded['songs'][0]['metadata']['artist'],
          extras: {
            'path': decoded['songs'][0]['filepath'],
            'year': decoded['songs'][0]['year'],
            'artUrl': artUrl,
          });

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
