import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mstream_music/main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'playback_backend.dart';
import 'local_playback_backend.dart';
import 'dlna_playback_backend.dart';
import 'chromecast_playback_backend.dart';
import 'local_media_server.dart';
import 'cast_log.dart';
import 'cast_target.dart';
import '../objects/server.dart';
import '../objects/metadata.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/cast_manager.dart';
import '../singletons/settings.dart';
import '../util/camelot.dart';

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  // Playback is delegated to a swappable backend so casting can move audio
  // off-device without changing the queue / Auto-DJ / shuffle / repeat logic
  // here. The active backend lives in a BehaviorSubject; the handler's derived
  // streams switchMap over it so existing listeners auto-resubscribe when the
  // backend swaps (see positionStream and _init). The local just_audio backend
  // is persistent (reused when switching back from a cast device); remote
  // backends are built per-session and disposed on switch-away.
  final LocalPlaybackBackend _localBackend = LocalPlaybackBackend();
  late final BehaviorSubject<PlaybackBackend> _backendSubject =
      BehaviorSubject<PlaybackBackend>.seeded(_localBackend);
  PlaybackBackend get _backend => _backendSubject.value;

  // Serializes cast-target switches so rapid re-selection can't interleave two
  // _switchBackend calls (racing on _backend / dispose).
  Future<void> _switchChain = Future<void>.value();

  // Android-only native equalizer, exposed for the EQ screen. Lives on the
  // local backend (null on non-Android / remote backends). eq_screen.dart
  // reads this via MediaManager().audioHandler.equalizer.
  AndroidEqualizer? get equalizer => _backend.equalizer;

  int? get index => _backend.currentIndex;

  /// Live playback position of the active backend (read by QueueStore so the
  /// saved snapshot carries the exact spot in the current track).
  Duration get position => _backend.position;

  Stream<Duration> get positionStream =>
      _backendSubject.switchMap((b) => b.positionStream);

  // Android audio session id of the active backend. The visualizer's
  // real-audio capture attaches a Visualizer to THIS session — the
  // global output mix (session 0) is blocked for normal apps on modern
  // Android. Null until a source has loaded (or while casting).
  int? get androidAudioSessionId => _backend.androidAudioSessionId;

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
    // These derived streams switchMap over the active backend so they keep
    // working across a cast backend swap — the new backend's streams are
    // subscribed automatically and the old ones cancelled.
    _backendSubject.switchMap((b) => b.currentIndexStream).listen((index) {
      // A reorder re-points the backend's currentIndex without playback
      // advancing, so skip the Auto-DJ top-up (and the now-playing re-emit) —
      // otherwise dragging the playing track to the last slot would append a
      // spurious Auto-DJ track.
      if (_reordering) return;
      if (index == queue.value.length - 1) {
        autoDJ();
      }
      _emitCurrentMediaItem();
    });
    // duration usually arrives via durationStream after the source
    // loads. Re-emit the current MediaItem with the duration filled in
    // so the BottomBar progress formula stops dividing by 1.
    _backendSubject
        .switchMap((b) => b.durationStream)
        .listen((_) => _emitCurrentMediaItem());
    // Propagate backend state changes to AudioService clients.
    _backendSubject
        .switchMap((b) => b.changeStream)
        .listen((_) => _broadcastState());
    // Stop the service when playback reaches the end of the queue.
    _backendSubject.switchMap((b) => b.processingStateStream).listen((state) {
      if (state == BackendProcessingState.completed) stop();
    });
    // A remote backend that loses its renderer mid-cast (TV off, Wi-Fi drop)
    // emits here; fall back to local playback at the same spot + a toast.
    _backendSubject
        .switchMap((b) => b.rendererLostStream)
        .listen(_onRendererLost);
    // Route cast-target selection (from the picker) to a backend swap.
    CastManager().onTargetSelected = _switchToTarget;
    try {
      // Seed the backend with whatever is already in the queue
      // (typically empty on cold start).
      await _backend.setSources(queue.value);
    } catch (e) {
      castLog('Error seeding playback backend', error: e);
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
    if (_reordering) return;
    if (queue.value.isEmpty) return;
    final i = (index ?? 0).clamp(0, queue.value.length - 1);
    final item = queue.value[i];
    final dur = _backend.duration;
    mediaItem.add(dur != null ? item.copyWith(duration: dur) : item);
  }

  /// Switch playback to a [CastTarget] chosen in the cast picker. Builds the
  /// matching backend (the persistent local just_audio backend, or a fresh
  /// DLNA session) and hands it the current queue + position so playback
  /// continues on the new device. Wired to CastManager.onTargetSelected.
  Future<void> _switchToTarget(CastTarget target, bool visualizer) {
    _switchChain = _switchChain
        .then((_) => _doSwitchToTarget(target, visualizer))
        .catchError((Object e) {
      castLog('Cast backend switch failed', error: e);
    });
    return _switchChain;
  }

  Future<void> _doSwitchToTarget(CastTarget target, bool visualizer) async {
    final PlaybackBackend next;
    if (target.isLocal) {
      next = _localBackend;
    } else if (target.kind == CastTargetKind.dlna) {
      next = DlnaPlaybackBackend(udn: target.id);
    } else if (target.kind == CastTargetKind.chromecast) {
      // visualizer = stream the on-device visualizer (video) instead of audio.
      next = ChromecastPlaybackBackend(
          deviceId: target.id, visualizer: visualizer);
    } else {
      return;
    }
    if (identical(next, _backend)) return;
    await _switchBackend(next);
  }

  // Carry the current position / index / playing state + shuffle/repeat to the
  // new backend, make it active (switchMap re-subscribes the derived streams),
  // resume, then tear down the previous backend if it was a per-session remote
  // one (the local backend is persistent and reused).
  Future<void> _switchBackend(PlaybackBackend next) async {
    final prev = _backend;
    final pos = prev.position;
    final idx = prev.currentIndex ?? 0;
    final wasPlaying = prev.playing;

    await prev.pause();

    await next.setShuffleEnabled(prev.shuffleEnabled);
    await next.setRepeatAll(prev.repeatAll);
    await next.setSources(queue.value);
    _backendSubject.add(next);
    if (queue.value.isNotEmpty) {
      // Carry the play state into the load: a renderer then auto-plays when its
      // media is ready (no load-paused-then-race-play), and we don't await the
      // local backend's play() — whose future only completes on pause/stop, so
      // awaiting it here used to block the switch and leave the cast session
      // connected until the user hit pause.
      await next.seek(pos, index: idx, play: wasPlaying);
    }
    _broadcastState();

    // The remote backends swallow load/connection errors internally (so they
    // never throw here); detect a failed cast by whether playback actually
    // starts. If the renderer is unreachable / a Cast session won't connect /
    // the media is unplayable, fall back to local so playback isn't left
    // silently dead, and surface a toast.
    final isRemote = !identical(next, _localBackend);
    if (isRemote && wasPlaying && queue.value.isNotEmpty) {
      final started = await _awaitRemoteStart(next);
      if (!started) {
        await _fallBackToLocal(prev, next, pos, idx);
        return;
      }
    }

    if (!identical(prev, _localBackend)) {
      await prev.dispose();
    }
    // Switched back to the phone — tear down the local file server (no-op if it
    // was never started). A remote→remote switch keeps it up for the new one.
    if (identical(next, _localBackend)) {
      await LocalMediaServer().stop();
    }
  }

  // True once a freshly-activated remote backend actually starts (reaches
  // ready/playing) within a timeout; false if it stays stuck loading (renderer
  // unreachable / session won't connect / unplayable media).
  Future<bool> _awaitRemoteStart(PlaybackBackend backend) async {
    bool started(BackendProcessingState s) =>
        s == BackendProcessingState.ready ||
        s == BackendProcessingState.completed;
    if (started(backend.processingState)) return true;
    try {
      await backend.processingStateStream
          .firstWhere(started)
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  // A cast failed to start — resume on the phone at the same spot, tear down
  // the failed (and abandoned previous) remote backend, and tell CastManager
  // so the UI reverts to "This device" and shows a message.
  Future<void> _fallBackToLocal(PlaybackBackend prev, PlaybackBackend failed,
      Duration pos, int idx) async {
    await failed.pause();
    await _localBackend.setSources(queue.value);
    _backendSubject.add(_localBackend);
    if (queue.value.isNotEmpty) {
      await _localBackend.seek(pos, index: idx, play: true);
    }
    _broadcastState();
    if (!identical(failed, _localBackend)) await failed.dispose();
    if (!identical(prev, _localBackend) && !identical(prev, failed)) {
      await prev.dispose();
    }
    await LocalMediaServer().stop();
    CastManager().reportCastFailed(
        "Couldn't play on the cast device — back on this phone");
  }

  // A remote renderer dropped offline *during* playback (not at switch time —
  // that's _fallBackToLocal). Resume on the phone at the current spot and tell
  // CastManager (reverts the UI to "This device" + toast). Serialized through
  // _switchChain so it can't interleave with a user-initiated target switch.
  void _onRendererLost(String message) {
    _switchChain = _switchChain.then((_) async {
      final failed = _backend;
      if (identical(failed, _localBackend)) return; // already recovered
      final pos = failed.position;
      final idx = failed.currentIndex ?? 0;
      final wasPlaying = failed.playing;
      await _localBackend.setSources(queue.value);
      _backendSubject.add(_localBackend);
      if (queue.value.isNotEmpty) {
        await _localBackend.seek(pos, index: idx, play: wasPlaying);
      }
      _broadcastState();
      await failed.dispose();
      await LocalMediaServer().stop();
      CastManager().reportCastFailed(message);
    }).catchError((Object e) {
      castLog('Renderer-lost fallback failed', error: e);
    });
  }

  @override
  BehaviorSubject<dynamic> customState =
      BehaviorSubject<dynamic>.seeded(CustomEvent(null));

  // True only while a queue reorder is rewiring the backend's source list.
  // moveAudioSource emits transient currentIndex values, so re-deriving the
  // now-playing MediaItem from queue.value[currentIndex] mid-reorder briefly
  // resolves to the *moved* item and flashes its art / title / waveform. The
  // playing track never changes during a reorder, so we hold the last good
  // MediaItem instead.
  bool _reordering = false;

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index > queue.value.length) return;
    // This jumps to the beginning of the queue item at newIndex.
    _backend.seek(Duration.zero, index: index);
  }

  /// Reinstate a persisted queue at launch WITHOUT auto-playing: seed the queue
  /// + backend sources, park playback at [index]/[position] paused, and restore
  /// shuffle/repeat. Used by QueueStore.init() so the app reopens exactly where
  /// it left off. No-op for an empty list.
  Future<void> restoreQueue(List<MediaItem> items, int index, Duration position,
      {bool shuffle = false, bool repeat = false}) async {
    if (items.isEmpty) return;
    queue.add(items.toList());
    await _backend.setSources(items);
    final int i = index.clamp(0, items.length - 1);
    // play: false → load paused at the saved spot (don't blast audio on open).
    await _backend.seek(position, index: i, play: false);
    if (repeat) await _backend.setRepeatAll(true);
    if (shuffle) await _backend.setShuffleEnabled(true);
    _emitCurrentMediaItem();
    _broadcastState();
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    queue.add(queue.value..add(item));
    // The backend extracts the playable URI (local backend) or builds renderer
    // metadata (cast backend) from the item itself. The offline-file detection
    // (File.existsSync + Uri.file) from the server-download-folder PR now lives
    // in LocalPlaybackBackend._uriFor.
    await _backend.addSource(item);
  }

  @override
  Future<void> play() => _backend.play();

  @override
  Future<void> pause() => _backend.pause();

  @override
  Future<void> skipToNext() async {
    _backend.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _backend.seekToPrevious();
  }

  @override
  Future<void> seek(Duration position) => _backend.seek(position);

  @override
  Future<void> stop() async {
    await _backend.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode doesntMatter) async {
    if (_backend.shuffleEnabled == true) {
      await _backend.setShuffleEnabled(false);
      await super.setShuffleMode(AudioServiceShuffleMode.none);
    } else {
      await _backend.setShuffleEnabled(true);
      await super.setShuffleMode(AudioServiceShuffleMode.all);
    }

    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode doesntMatter) async {
    if (_backend.repeatAll == true) {
      await _backend.setRepeatAll(false);
      await super.setRepeatMode(AudioServiceRepeatMode.none);
    } else {
      await _backend.setRepeatAll(true);
      await super.setRepeatMode(AudioServiceRepeatMode.all);
    }

    _broadcastState();
  }

  @override
  Future<void> removeQueueItem(MediaItem i) async {
    await super.removeQueueItem(i);
    // TODO: See removeQueueItemAt
  }

  @override
  Future<void> removeQueueItemAt(int i) async {
    await super.removeQueueItemAt(i);
    // Update the queue BEFORE the backend. removeSourceAt makes the backend emit
    // its new currentIndex, and the currentIndexStream listener re-derives the
    // now-playing item as queue.value[index]. If the queue still held the
    // removed item, the wrong row would briefly render as the active/playing row
    // (a flash in the accent colour) before correcting — same root cause as the
    // reorder flash. Reordering keeps the queue and the emitted index in sync.
    queue.add(queue.value..removeAt(i));
    await _backend.removeSourceAt(i);
  }

  customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'clearPlaylist':
        await _backend.stop();
        await super.stop();
        await _backend.clearSources();
        queue.add(queue.value..clear());
        _broadcastState();
        break;
      case 'moveQueueItem':
        // Drag-to-reorder. [to] is the post-removal target index
        // (ReorderableListView convention). Reorder the queue list first, then
        // the backend's source list, so the backend's current-index emit lands
        // against the already-updated queue.
        final from = extras?['from'];
        final to = extras?['to'];
        if (from is int && to is int) {
          final q = queue.value;
          if (from >= 0 &&
              from < q.length &&
              to >= 0 &&
              to < q.length &&
              from != to) {
            final item = q.removeAt(from);
            q.insert(to, item);
            queue.add(q);
            // Hold the now-playing item steady while the backend rewires its
            // source order, so its art/title/waveform don't flash the moved
            // track as the backend's currentIndex transiently re-points.
            _reordering = true;
            try {
              await _backend.moveSource(from, to);
            } finally {
              _reordering = false;
            }
            _broadcastState();
          }
        }
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
              _backend.processingState == BackendProcessingState.idle) {
            autoDJ(autoPlay: true, incrementIndex: true);
          } else {
            autoDJ();
          }
        }

        break;
    }
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState() {
    final playing = _backend.playing;
    final AudioServiceShuffleMode shuffle = _backend.shuffleEnabled == true
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;

    final AudioServiceRepeatMode repeat = _backend.repeatAll == true
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
      processingState: const {
        BackendProcessingState.idle: AudioProcessingState.idle,
        BackendProcessingState.loading: AudioProcessingState.loading,
        BackendProcessingState.buffering: AudioProcessingState.buffering,
        BackendProcessingState.ready: AudioProcessingState.ready,
        BackendProcessingState.completed: AudioProcessingState.completed,
      }[_backend.processingState]!,
      playing: playing,
      updatePosition: _backend.position,
      bufferedPosition: _backend.bufferedPosition,
      speed: _backend.speed,
      queueIndex: _backend.currentIndex,
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

    // Parse the raw server map once so the genre / disc / key wire quirks are
    // handled in one place (MusicMetadata.fromServerMap) — the same path that
    // browse-added items take.
    final meta = MusicMetadata.fromServerMap(metadata);
    final item = MediaItem(
      id: mediaUrl,
      title: meta.title ?? filepath.split('/').last,
      album: meta.album,
      artist: meta.artist,
      genre: meta.genreLabel,
      extras: {
        // Tag with the source server so Share Playlist's multi-server
        // detection recognises AutoDJ-added songs as shareable.
        'server': autoDJServer!.localname,
        'path': filepath,
        'year': meta.year,
        'track': meta.track,
        'disc': meta.disc,
        'artUrl': artUrl,
        // bpm + musicalKey power the next AutoDJ pick's continuity payload
        // (see autoDJ() above), stashed under our camelCase keys for
        // consistency with browser-added items.
        'bpm': meta.bpm,
        'musicalKey': meta.musicalKey,
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
      _backend.seek(Duration.zero, index: index! + 1);
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
