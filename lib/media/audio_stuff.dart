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
import '../singletons/auto_dj_manager.dart';
import '../singletons/settings.dart';
import '../util/camelot.dart';

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

  // Session-only: the Camelot anchor for harmonic mixing. Locked on
  // the first DJ-picked song with a recognised key (after that, every
  // subsequent pick uses the anchor's 6 Camelot neighbours, keeping
  // the session musically coherent rather than drifting). Reset on
  // setAutoDJ off or server switch.
  String? _camelotAnchor;

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
          _camelotAnchor = null;
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

    // Keyword filter is client-side (the server doesn't see it).
    // Retry up to 5 times if responses get blocked, using the
    // updated ignoreList from the server so we don't pick the same
    // rejected track twice. After 5 blocks accept the last response
    // anyway — mirrors the webapp's fallback so the queue doesn't
    // stall forever on an over-aggressive filter.
    for (var attempt = 0; attempt < 5; attempt++) {
      final payload = <String, dynamic>{
        'ignoreList': jsonAutoDJIgnoreList ?? [],
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
        final res = await http.post(
          Uri.parse(autoDJServer!.url).resolve('/api/v1/db/random-songs'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': autoDJServer?.jwt ?? '',
          },
          body: jsonEncode(payload),
        );
        if (res.statusCode > 299) return; // server error → bail silently
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return; // network error → bail silently (matches old behaviour)
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
    final filepath = song['filepath'] as String;

    String p = '';
    for (final segment in filepath.split('/')) {
      if (segment.isEmpty) continue;
      p += '/' + Uri.encodeComponent(segment);
    }

    final mediaUrl = autoDJServer!.url +
        '/media' +
        p +
        '?app_uuid=' +
        Uuid().v4() +
        (autoDJServer?.jwt == null ? '' : '&token=' + autoDJServer!.jwt!);

    final artUrl = metadata['album-art'] != null
        ? Uri.parse(autoDJServer!.url)
            .resolve('/album-art/' +
                metadata['album-art'] +
                '?compress=l&token=' +
                (autoDJServer?.jwt ?? ''))
            .toString()
        : null;

    final item = MediaItem(
      id: mediaUrl,
      title: metadata['title'] ?? filepath.split('/').last,
      album: metadata['album'],
      artist: metadata['artist'],
      extras: {
        // Tag with the source server so Share Playlist's multi-server
        // detection recognises AutoDJ-added songs as shareable.
        'server': autoDJServer!.localname,
        'path': filepath,
        'year': metadata['year'],
        'artUrl': artUrl,
        // bpm + musicalKey power the next AutoDJ pick's continuity
        // payload (see autoDJ() above). 'musical-key' is the wire
        // shape from the server — we stash it under our camelCase
        // key for consistency with browser-added items.
        'bpm': metadata['bpm'],
        'musicalKey': metadata['musical-key'],
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

    if (incrementIndex == true && index != null) {
      _player.seek(Duration.zero, index: index! + 1);
    }
    if (autoPlay == true) {
      play();
    }
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
