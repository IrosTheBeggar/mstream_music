import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../media/audio_stuff.dart';
import '../objects/play_event.dart';
import '../util/stream_url.dart';
import '../util/write_chain.dart';
import 'log_manager.dart';
import 'media.dart';
import 'server_list.dart';

/// Why a session is being closed. Decides the outcome together with where
/// the track was when it closed (see [PlaySessionFold.outcomeFor]).
enum PlayCloseReason {
  /// Another track became current (natural advance, skip, removal, jump).
  trackChanged,

  /// The backend reported the end of the queue.
  queueEnd,

  /// A deliberate stop, a cleared queue, or an emptied queue.
  stopped,

  /// The session was recovered from a checkpoint after the process died.
  recovered,
}

/// One track's open play session: immutable, advanced by [PlaySessionFold].
class PlaySession {
  final String key;
  final TrackFacts track;
  final DateTime startedAt;
  final PlaySource source;
  final int playedMs;
  final int pauseCount;
  final bool playing;

  /// The last position sample and when it was taken; null before the first.
  final Duration? lastPos;
  final DateTime? lastSampleAt;

  /// True after a user seek until the next position sample: that sample's
  /// jump is the seek, not listening.
  final bool seekPending;

  const PlaySession({
    required this.key,
    required this.track,
    required this.startedAt,
    required this.source,
    this.playedMs = 0,
    this.pauseCount = 0,
    this.playing = true,
    this.lastPos,
    this.lastSampleAt,
    this.seekPending = false,
  });

  PlaySession copyWith({
    TrackFacts? track,
    int? playedMs,
    int? pauseCount,
    bool? playing,
    Duration? lastPos,
    DateTime? lastSampleAt,
    bool? seekPending,
  }) =>
      PlaySession(
        key: key,
        track: track ?? this.track,
        startedAt: startedAt,
        source: source,
        playedMs: playedMs ?? this.playedMs,
        pauseCount: pauseCount ?? this.pauseCount,
        playing: playing ?? this.playing,
        lastPos: lastPos ?? this.lastPos,
        lastSampleAt: lastSampleAt ?? this.lastSampleAt,
        seekPending: seekPending ?? this.seekPending,
      );

  /// The checkpoint shape (see [PlayTracker.checkpointNow]): enough to close
  /// the session as `stopped` on the next launch if this process dies.
  Map<String, dynamic> toCheckpoint(DateTime at) => {
        'v': PlayEvent.schemaVersion,
        'key': key,
        't': startedAt.millisecondsSinceEpoch,
        'at': at.millisecondsSinceEpoch,
        's': source.name,
        'pl': playedMs,
        'pz': pauseCount,
        ...track.toJson(),
      };
}

/// Pure transitions over [PlaySession]. No streams, no clocks of its own —
/// every rule the tracker applies lives here so it can be unit-tested with
/// a hand-fed sequence of samples.
class PlaySessionFold {
  PlaySessionFold._();

  /// How close to the end counts as "reached the end": the position a
  /// player reports when a track completes can stop short of the duration.
  static const Duration endGuard = Duration(seconds: 2);

  /// A position under this, right after one at the end, is the same track
  /// starting over (repeat-one, or a replay) rather than a seek.
  static const Duration restartMax = Duration(seconds: 1);

  /// A position delta is listening when it moved forward by no more than
  /// this factor of the wall-clock gap between samples (2x playback speed
  /// is the ceiling anyone uses) plus a little jitter. A seek jumps further;
  /// a stall moves nothing; a backwards jump is never listening.
  static const double maxRate = 2.5;
  static const Duration jitter = Duration(milliseconds: 250);

  static bool reachedEnd(Duration? pos, int? durationMs) {
    if (pos == null || durationMs == null || durationMs <= 0) return false;
    return pos.inMilliseconds >= durationMs - endGuard.inMilliseconds;
  }

  /// Fold one position sample. `restarted` is true when the same track
  /// started over (the caller closes the session as completed and opens a
  /// fresh one); the returned session is the one to keep either way.
  static ({PlaySession session, bool restarted}) onPosition(
      PlaySession s, Duration pos, DateTime now) {
    final last = s.lastPos;
    final lastAt = s.lastSampleAt;
    if (last == null || lastAt == null) {
      return (session: s.copyWith(lastPos: pos, lastSampleAt: now), restarted: false);
    }
    if (!s.seekPending &&
        s.playing &&
        pos < restartMax &&
        reachedEnd(last, s.track.durationMs)) {
      return (session: s.copyWith(lastPos: pos, lastSampleAt: now), restarted: true);
    }
    var played = s.playedMs;
    if (s.playing && !s.seekPending) {
      final delta = pos - last;
      final wall = now.difference(lastAt);
      final ceiling = wall.inMilliseconds * maxRate + jitter.inMilliseconds;
      if (delta > Duration.zero && delta.inMilliseconds <= ceiling) {
        played += delta.inMilliseconds;
      }
    }
    return (
      session: s.copyWith(
          playedMs: played, lastPos: pos, lastSampleAt: now, seekPending: false),
      restarted: false
    );
  }

  /// Playing flipped. A pause counts once, on the way down.
  static PlaySession onPlaying(PlaySession s, bool playing) {
    if (s.playing == playing) return s;
    return s.copyWith(
        playing: playing, pauseCount: s.pauseCount + (playing ? 0 : 1));
  }

  /// A user seek: the next sample's jump is not listening.
  static PlaySession onSeek(PlaySession s) => s.copyWith(seekPending: true);

  /// The backend learned (or corrected) the track's duration.
  static PlaySession onDuration(PlaySession s, int? durationMs) =>
      durationMs == null || durationMs == s.track.durationMs
          ? s
          : s.copyWith(track: s.track.withDuration(durationMs));

  static PlayOutcome outcomeFor(PlaySession s, PlayCloseReason reason) {
    switch (reason) {
      case PlayCloseReason.queueEnd:
        return PlayOutcome.completed;
      case PlayCloseReason.stopped:
      case PlayCloseReason.recovered:
        return PlayOutcome.stopped;
      case PlayCloseReason.trackChanged:
        return reachedEnd(s.lastPos, s.track.durationMs)
            ? PlayOutcome.completed
            : PlayOutcome.skipped;
    }
  }

  /// Close [s] into an event. Pure: the id and the clock are inputs.
  static PlayEvent close(PlaySession s, PlayCloseReason reason, DateTime now,
      {required String id}) {
    final ended = now.isBefore(s.startedAt) ? s.startedAt : now;
    return PlayEvent(
      id: id,
      startedAt: s.startedAt,
      endedAt: ended,
      track: s.track,
      playedMs: s.playedMs,
      outcome: outcomeFor(s, reason),
      source: s.source,
      pauseCount: s.pauseCount,
      counted:
          countsAsPlay(playedMs: s.playedMs, durationMs: s.track.durationMs),
    );
  }

  /// Rebuild the event for a checkpointed session found on launch: closed
  /// as `stopped` at the checkpoint's own time, with what it had listened
  /// by then. Null when the checkpoint is not a complete one.
  static PlayEvent? recover(Map<dynamic, dynamic> j, {required String id}) {
    final t = j['t'];
    final pl = j['pl'];
    if (t is! int || pl is! int) return null;
    final track = TrackFacts.fromJson(j);
    if (track == null) return null;
    final at = j['at'] is int ? j['at'] as int : t + pl;
    final source = PlaySource.values.cast<PlaySource?>().firstWhere(
            (s) => s!.name == j['s'],
            orElse: () => null) ??
        PlaySource.other;
    return PlayEvent(
      id: id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
      endedAt: DateTime.fromMillisecondsSinceEpoch(at < t ? t : at, isUtc: true),
      track: track,
      playedMs: pl,
      outcome: PlayOutcome.stopped,
      source: source,
      pauseCount: j['pz'] is int ? j['pz'] as int : 0,
      counted: countsAsPlay(playedMs: pl, durationMs: track.durationMs),
    );
  }
}

/// Turns what the audio handler plays into [PlayEvent]s.
///
/// One subscriber on the handler's existing streams — `mediaItem`,
/// `playbackState`, `positionStream`, `seekEvents` — so local playback, a
/// cast renderer, Android Auto and CarPlay all look the same here. A session
/// opens the first time the current track is actually playing (a restore
/// parks a track paused; that is not a listen) and closes when the track
/// changes, the queue ends, playback stops, or the process dies — the last
/// through a small checkpoint file, closed as `stopped` on the next launch.
///
/// Closed events go out on [events] and stay in [recent]; nothing is
/// written to disk here beyond the checkpoint. Persistence and server sync
/// subscribe to [events].
class PlayTracker {
  PlayTracker._();
  static final PlayTracker _instance = PlayTracker._();
  factory PlayTracker() => _instance;

  static const Duration _checkpointDebounce = Duration(seconds: 5);
  static const int _recentCap = 500;

  final StreamController<PlayEvent> _events =
      StreamController<PlayEvent>.broadcast();
  Stream<PlayEvent> get events => _events.stream;

  final List<PlayEvent> _recent = [];
  List<PlayEvent> get recent => List.unmodifiable(_recent);

  PlaySession? _open;
  PlaySession? get openSession => _open;

  /// The current item while no session is open — a track parked paused. It
  /// opens the moment playback actually starts on it.
  MediaItem? _pending;
  bool _playing = false;
  bool _shuffle = false;
  bool _started = false;
  final List<StreamSubscription> _subs = [];
  Timer? _checkpointTimer;
  final WriteChain _chain = WriteChain();

  Future<File> get _checkpointFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/play_session.json');
  }

  /// Call ONCE after the server list has loaded (peer ids resolve through
  /// it) — alongside QueueStore.init.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _recoverCheckpoint();
    } catch (e) {
      appLog('[history] checkpoint recovery failed: $e');
    }
    _attach();
  }

  void _attach() {
    final handler = MediaManager().audioHandler;
    _subs.add(handler.mediaItem.listen(_onMediaItem));
    _subs.add(handler.playbackState.listen(_onPlaybackState));
    _subs.add(handler.positionStream.listen(_onPosition));
    _subs.add(handler.seekEvents.listen((_) => _onSeek()));
  }

  void dispose() {
    _checkpointTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  // ── Signals ──

  void _onMediaItem(MediaItem? item) {
    final key = trackKeyOf(item);
    final open = _open;
    if (open != null) {
      if (key == open.key) {
        _open = PlaySessionFold.onDuration(open, item?.duration?.inMilliseconds);
        return;
      }
      _close(PlayCloseReason.trackChanged);
    }
    if (item == null || key == null) {
      _pending = null;
      return;
    }
    if (_playing) {
      _openFor(item);
    } else {
      _pending = item;
    }
  }

  void _onPlaybackState(PlaybackState st) {
    _shuffle = st.shuffleMode == AudioServiceShuffleMode.all;
    _playing = st.playing;
    final open = _open;
    if (st.processingState == AudioProcessingState.completed) {
      if (open != null) _close(PlayCloseReason.queueEnd);
      return;
    }
    if (st.processingState == AudioProcessingState.idle) {
      if (open != null) _close(PlayCloseReason.stopped);
      return;
    }
    if (open == null) {
      if (st.playing) {
        final item = _pending ?? MediaManager().audioHandler.mediaItem.valueOrNull;
        if (item != null && trackKeyOf(item) != null) _openFor(item);
      }
      return;
    }
    if (open.playing != st.playing) {
      _open = PlaySessionFold.onPlaying(open, st.playing);
      _scheduleCheckpoint();
    }
  }

  void _onPosition(Duration pos) {
    final open = _open;
    if (open == null) return;
    final r = PlaySessionFold.onPosition(open, pos, DateTime.now());
    if (r.restarted) {
      final item = MediaManager().audioHandler.mediaItem.valueOrNull;
      _open = r.session;
      _close(PlayCloseReason.queueEnd);
      if (item != null && trackKeyOf(item) == open.key) _openFor(item);
      return;
    }
    final grew = r.session.playedMs != open.playedMs;
    _open = r.session;
    if (grew) _scheduleCheckpoint();
  }

  void _onSeek() {
    final open = _open;
    if (open != null) _open = PlaySessionFold.onSeek(open);
  }

  // ── Sessions ──

  void _openFor(MediaItem item) {
    final key = trackKeyOf(item);
    if (key == null) return;
    final handler = MediaManager().audioHandler;
    // Best-effort provenance: Auto DJ running means its picks are what is
    // playing; shuffle is a mode; everything else is a manual queue. Tagging
    // each queue item with its origin (Android Auto, CarPlay, cast) is a
    // follow-up.
    final source = handler.autoDJServer != null
        ? PlaySource.autodj
        : _shuffle
            ? PlaySource.shuffle
            : PlaySource.manual;
    _pending = null;
    _open = PlaySession(
      key: key,
      track: factsFor(item),
      startedAt: DateTime.now().toUtc(),
      source: source,
      playing: true,
    );
    _scheduleCheckpoint();
  }

  void _close(PlayCloseReason reason) {
    final open = _open;
    if (open == null) return;
    _open = null;
    _checkpointTimer?.cancel();
    final event = PlaySessionFold.close(open, reason, DateTime.now().toUtc(),
        id: const Uuid().v4());
    _record(event);
    _chain.run(() async {
      final f = await _checkpointFile;
      if (await f.exists()) await f.delete();
    });
  }

  void _record(PlayEvent event) {
    _recent.add(event);
    if (_recent.length > _recentCap) {
      _recent.removeRange(0, _recent.length - _recentCap);
    }
    final t = event.track;
    final dur = t.durationMs == null ? '?' : '${t.durationMs! ~/ 1000}';
    appLog('[history] ${event.outcome.name} '
        '${event.counted ? 'play' : 'no-play'} '
        '${event.playedMs ~/ 1000}s/${dur}s '
        '"${t.title ?? t.path}" src=${event.source.name}'
        '${t.peerId != null ? ' peer=${t.peerId}' : ''}'
        '${t.isLocalFile ? ' local' : ''}');
    if (!_events.isClosed) _events.add(event);
  }

  // ── Checkpoint ──

  void _scheduleCheckpoint() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer(_checkpointDebounce, checkpointNow);
  }

  /// Write the open session now (lifecycle pause / detach) so an OS kill
  /// still yields a `stopped` event with what was listened so far.
  Future<void> checkpointNow() async {
    _checkpointTimer?.cancel();
    final open = _open;
    if (open == null) return;
    final content = jsonEncode(open.toCheckpoint(DateTime.now().toUtc()));
    try {
      await _chain.run(() async => (await _checkpointFile).writeAsString(content));
    } catch (e) {
      appLog('[history] checkpoint write failed: $e');
    }
  }

  Future<void> _recoverCheckpoint() async {
    final f = await _checkpointFile;
    if (!await f.exists()) return;
    PlayEvent? event;
    try {
      final v = jsonDecode(await f.readAsString());
      if (v is Map) {
        event = PlaySessionFold.recover(v, id: const Uuid().v4());
      }
    } catch (_) {
      // A torn file from a kill mid-write: nothing to recover.
    }
    await f.delete();
    if (event != null) {
      appLog('[history] recovered a session cut short by a kill');
      _record(event);
    }
  }

  // ── Track facts ──

  /// The tracker's identity for [item] — the handler's server + path key —
  /// or null for nothing / the blank now-playing placeholder.
  static String? trackKeyOf(MediaItem? item) {
    if (item == null || item.id.isEmpty) return null;
    return AudioPlayerHandler.trackKey(item);
  }

  /// Copy what an event needs out of a queue item. The peer id comes from
  /// the server record: a federated server's own id on its parent.
  static TrackFacts factsFor(MediaItem item) {
    final extras = item.extras ?? const <String, dynamic>{};
    final server = extras['server'] as String? ?? '';
    final artUrl = extras['artUrl'];
    return TrackFacts(
      server: server,
      peerId: server.isEmpty
          ? null
          : ServerManager().byLocalname(server)?.federationPeerId,
      path: extras['path'] as String? ?? item.id,
      hash: extras['hash'] as String?,
      title: item.title.isEmpty ? null : item.title,
      artist: item.artist,
      album: item.album,
      artFile: artUrl is String ? albumArtFileFromUrl(artUrl) : null,
      durationMs: item.duration?.inMilliseconds,
    );
  }
}
