import 'dart:async';
import 'dart:math' show Random;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart' show AndroidEqualizer;
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'playback_backend.dart';

/// Shared base for the renderer backends (DLNA, Chromecast) that *emulate*
/// just_audio's playlist: the remote device plays one track at a time, so each
/// backend keeps the source list + current index on the phone, pushes the
/// current track to the renderer, and advances when the renderer reports the
/// track ended.
///
/// This base owns the parts that are identical across those backends and must
/// never silently drift between them:
///   * the source list ([items]) and the two index pointers ([index] /
///     [loadedIndex]), plus all the add / remove / move / clear index
///     arithmetic (the subtle asymmetric shift in [moveSource] in particular);
///   * shuffle / repeat state and the [nextIndex] selection;
///   * the rxdart subjects and the broadcast / emit boilerplate.
///
/// Renderer-specific work — actually loading a track onto the device,
/// transport, position/duration/state tracking, teardown — is left to
/// subclasses through a few hooks ([loadIndex], [stopForEmptyList],
/// [disposeRenderer]) plus the [PlaybackBackend] transport methods the base
/// leaves abstract (play/pause/stop/seek/…/setVolume).
///
/// The local just_audio backend does NOT extend this: just_audio owns its own
/// playlist and index math, so `LocalPlaybackBackend` stays a thin
/// pass-through.
abstract class EmulatedPlaylistBackend implements PlaybackBackend {
  // ── Source list + index state (the single source of truth) ──
  List<MediaItem> _items = <MediaItem>[];
  int _index = -1; // logical current index into _items
  int _loadedIndex = -1; // index actually pushed to the renderer
  bool _shuffle = false;
  BackendRepeat _repeat = BackendRepeat.off;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  BackendProcessingState _state = BackendProcessingState.idle;
  final Random _rng = Random();

  /// Read-only view of the source list for subclasses. The list is mutated
  /// only by the source-list methods below; subclasses read it
  /// (`items[index]`, `items.length`) from their renderer / transport code.
  @protected
  List<MediaItem> get items => _items;

  /// Logical current index into [items] (the track the handler considers
  /// "current"). Subclasses set it as they load tracks / advance.
  @protected
  int get index => _index;
  @protected
  set index(int value) => _index = value;

  /// Index actually pushed to the renderer. Kept in lockstep with [index] once
  /// a track is loaded (the `loadedIndex == index` invariant), and reset to -1
  /// when the loaded track is invalidated (removed, or list emptied).
  @protected
  int get loadedIndex => _loadedIndex;
  @protected
  set loadedIndex(int value) => _loadedIndex = value;

  // ── rxdart subjects (owned here; subclasses emit via the helpers below) ──
  final BehaviorSubject<int?> _indexSubject = BehaviorSubject<int?>.seeded(null);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject =
      BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<BackendProcessingState> _stateSubject =
      BehaviorSubject<BackendProcessingState>.seeded(
          BackendProcessingState.idle);
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  // Emits when the renderer is lost mid-cast (TV powered off, Wi-Fi dropped,
  // Cast session ended unexpectedly); the handler falls back to local playback.
  final PublishSubject<String> _rendererLost = PublishSubject<String>();

  // isClosed-guarded emitters: an in-flight poll / status callback / auto-advance
  // can complete after dispose() has closed the subjects (we switched away
  // mid-operation), and adding to a closed subject throws.
  @protected
  void emitIndex(int? value) {
    if (!_indexSubject.isClosed) _indexSubject.add(value);
  }

  @protected
  void emitPos(Duration value) {
    if (!_positionSubject.isClosed) _positionSubject.add(value);
  }

  @protected
  void emitDur(Duration? value) {
    if (!_durationSubject.isClosed) _durationSubject.add(value);
  }

  @protected
  void change() {
    if (!_changeController.isClosed) _changeController.add(null);
  }

  @protected
  void setProcessingState(BackendProcessingState s) {
    _state = s;
    if (!_stateSubject.isClosed) _stateSubject.add(s);
  }

  @protected
  void emitRendererLost(String message) {
    if (!_rendererLost.isClosed) _rendererLost.add(message);
  }

  // ── Renderer hooks (implemented by each backend) ──
  /// Push [index] to the renderer and start / queue playback. Called both by a
  /// backend's own transport and by [removeSourceAt] when the playing track is
  /// removed and the slot it left behind must be (re)loaded.
  @protected
  Future<void> loadIndex(int index, {required bool play});

  /// Stop the renderer and settle the terminal (idle) state after the source
  /// list has been emptied (clearSources, or removing the last item). A hook
  /// because each backend stops differently (Cast `stop()` vs DLNA
  /// stop-renderer + idle state).
  @protected
  Future<void> stopForEmptyList();

  /// Backend-specific teardown (cancel subscriptions / polling, end the cast
  /// session). Called by [dispose] *before* the shared subjects are closed.
  @protected
  Future<void> disposeRenderer();

  // ── Source list (mirrors just_audio's on-player playlist API) ──
  @override
  Future<void> setSources(List<MediaItem> items,
      {int? initialIndex, Duration? initialPosition}) async {
    _items = List<MediaItem>.from(items);
    // Honour initialIndex so a reload/restore lands on the right track (no
    // index-0 flash). The renderer gets the position via the seek that follows;
    // initialPosition isn't needed here.
    _index = _items.isEmpty
        ? -1
        : (initialIndex != null &&
                initialIndex >= 0 &&
                initialIndex < _items.length
            ? initialIndex
            : 0);
    _loadedIndex = -1;
    emitIndex(_index < 0 ? null : _index);
    setProcessingState(_items.isEmpty
        ? BackendProcessingState.idle
        : BackendProcessingState.ready);
  }

  @override
  Future<void> addSource(MediaItem item) async {
    _items.add(item);
    if (_index == -1) {
      _index = 0;
      emitIndex(0);
      setProcessingState(BackendProcessingState.ready);
    }
  }

  @override
  Future<void> removeSourceAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    if (_items.isEmpty) {
      _index = -1;
      _loadedIndex = -1;
      emitIndex(null);
      await stopForEmptyList();
      return;
    }
    if (index < _index) {
      _index--;
      _loadedIndex--;
      emitIndex(_index);
    } else if (index == _index) {
      // Removed the now-playing track — advance to whatever now occupies this
      // slot (the former next track), clamping if it was the last.
      if (_index >= _items.length) _index = _items.length - 1;
      _loadedIndex = -1;
      emitIndex(_index);
      await loadIndex(_index, play: _playing);
    }
  }

  @override
  Future<void> moveSource(int from, int to) async {
    if (from < 0 ||
        from >= _items.length ||
        to < 0 ||
        to >= _items.length ||
        from == to) {
      return;
    }
    // Single-item-push model: reorder the internal list and shift the current /
    // loaded pointers so they follow the still-playing track to its new slot.
    // The renderer keeps playing that track — only the upcoming order changes,
    // so nothing is reloaded; the next advance just loads the new next item.
    final item = _items.removeAt(from);
    _items.insert(to, item);
    if (_index == from) {
      _index = to;
    } else if (_index >= 0) {
      if (from < _index) _index--;
      if (to <= _index) _index++;
    }
    if (_loadedIndex == from) {
      _loadedIndex = to;
    } else if (_loadedIndex >= 0) {
      if (from < _loadedIndex) _loadedIndex--;
      if (to <= _loadedIndex) _loadedIndex++;
    }
    if (_index >= 0) emitIndex(_index);
  }

  @override
  Future<void> clearSources() async {
    _items = <MediaItem>[];
    _index = -1;
    _loadedIndex = -1;
    emitIndex(null);
    await stopForEmptyList();
  }

  // ── Shuffle / repeat + next-track selection ──
  /// The index to advance to after the current track, honouring shuffle and
  /// repeat. Null means "nothing more to play" (end of a non-repeating list).
  /// Used by each backend's auto-advance ([onComplete] true) and seekToNext
  /// ([onComplete] false).
  @protected
  int? nextIndex({bool onComplete = false}) {
    if (_items.isEmpty) return null;
    // Repeat-one: a track that finished on its own replays; an explicit skip
    // (onComplete == false) still advances to the next track.
    if (onComplete && _repeat == BackendRepeat.one) return _index;
    if (_shuffle && _items.length > 1) {
      int n;
      do {
        n = _rng.nextInt(_items.length);
      } while (n == _index);
      return n;
    }
    if (_index + 1 < _items.length) return _index + 1;
    if (_repeat == BackendRepeat.all) return 0;
    return null;
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    _shuffle = enabled;
    change();
  }

  @override
  Future<void> setRepeat(BackendRepeat mode) async {
    _repeat = mode;
    change();
  }

  // ── Synchronous state (read by AudioPlayerHandler._broadcastState) ──
  @override
  bool get playing => _playing;
  @protected
  set playing(bool value) => _playing = value;
  @override
  bool get shuffleEnabled => _shuffle;
  @override
  BackendRepeat get repeat => _repeat;
  @override
  Duration get position => _position;
  @protected
  set position(Duration value) => _position = value;
  @override
  Duration get bufferedPosition => _position; // renderers expose no buffer info
  @override
  double get speed => 1.0;
  @override
  Duration? get duration => _duration;
  @protected
  set duration(Duration? value) => _duration = value;
  @override
  int? get currentIndex => _index < 0 ? null : _index;
  @override
  BackendProcessingState get processingState => _state;

  // ── Streams ──
  @override
  Stream<int?> get currentIndexStream => _indexSubject.stream;
  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;
  @override
  Stream<BackendProcessingState> get processingStateStream =>
      _stateSubject.stream;
  @override
  Stream<void> get changeStream => _changeController.stream;
  @override
  Stream<String> get rendererLostStream => _rendererLost.stream;
  // Cast backends report failures via rendererLostStream, not a local-player
  // error, so nothing emits here.
  @override
  Stream<Object> get errorStream => const Stream<Object>.empty();

  // ── Local-only capabilities (N/A while casting) ──
  @override
  bool get supportsEqualizer => false;
  @override
  AndroidEqualizer? get equalizer => null;
  @override
  int? get androidAudioSessionId => null;

  @override
  Future<void> dispose() async {
    await disposeRenderer();
    await _indexSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _stateSubject.close();
    await _changeController.close();
    await _rendererLost.close();
  }
}
