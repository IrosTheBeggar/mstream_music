import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart' show AndroidEqualizer;

/// Processing state of the active playback backend. Mirrors just_audio's
/// `ProcessingState` but is kept independent so remote (DLNA / Chromecast)
/// backends can report the same lifecycle without depending on just_audio.
enum BackendProcessingState { idle, loading, buffering, ready, completed }

/// Abstraction over "what actually plays the audio".
///
/// [AudioPlayerHandler] owns the queue, current index, shuffle/repeat and
/// Auto-DJ logic and delegates *only* transport to the active backend, then
/// re-broadcasts the backend's state through the existing audio_service
/// streams — so the UI never has to know which backend is active.
///
/// Today the only implementation is [LocalPlaybackBackend] (just_audio). The
/// casting backends (DLNA, Chromecast) will implement this same surface, with
/// the "single-item push" model hidden behind it: they keep the source list
/// and current index internally, push one track at a time to the renderer, and
/// emit [currentIndexStream] / [BackendProcessingState.completed] so the
/// handler's advance + Auto-DJ logic keeps working unchanged.
///
/// The surface deliberately mirrors just_audio's on-player playlist API so the
/// local implementation is a thin pass-through and the handler diff is minimal.
abstract class PlaybackBackend {
  // ── Source list (mirrors just_audio's on-player playlist API) ──
  // Takes [MediaItem]s (not bare URIs) so remote backends can build rich
  // metadata (title/artist/album/art) for the renderer; the local backend
  // extracts the playable URI itself.
  Future<void> setSources(List<MediaItem> items);
  Future<void> addSource(MediaItem item);
  Future<void> removeSourceAt(int index);

  /// Move the source at [from] to [to] (the post-removal target index, matching
  /// ReorderableListView), keeping the currently-playing item playing. The
  /// handler reorders the queue's MediaItem list in lockstep.
  Future<void> moveSource(int from, int to);
  Future<void> clearSources();

  // ── Transport ──
  Future<void> play();
  Future<void> pause();
  Future<void> stop();

  /// Seek within the current track, or (with [index]) jump to another item in
  /// the source list and seek within it. [play] forces the play state after the
  /// seek (true = play, false = pause, null = keep current) — used on a backend
  /// switch so a renderer loads already-playing via its native autoplay instead
  /// of loading paused and racing a follow-up play().
  Future<void> seek(Duration position, {int? index, bool? play});
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setRepeatAll(bool enabled);

  /// Output volume, 0.0–1.0. (Unused by the handler today; here for the cast
  /// backends + future ReplayGain/volume-normalization work.)
  Future<void> setVolume(double volume);

  // ── Synchronous state (read by AudioPlayerHandler._broadcastState) ──
  bool get playing;
  bool get shuffleEnabled;
  bool get repeatAll;
  Duration get position;
  Duration get bufferedPosition;
  double get speed;
  Duration? get duration;
  int? get currentIndex;
  BackendProcessingState get processingState;

  // ── Streams ──
  Stream<int?> get currentIndexStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<BackendProcessingState> get processingStateStream;

  /// Fires whenever any broadcast-relevant property changes (mirrors
  /// just_audio's `playbackEventStream`); the handler re-broadcasts its
  /// audio_service [PlaybackState] on each tick.
  Stream<void> get changeStream;

  /// Emits a user-facing reason when a remote renderer is lost *mid-playback*
  /// (TV powered off, Wi-Fi dropped, Cast session ended unexpectedly). The
  /// handler listens to the active backend's stream and falls back to local
  /// playback + a toast. Never emits on the local backend.
  Stream<String> get rendererLostStream;

  // ── Local-only capabilities (false / null on remote backends) ──
  bool get supportsEqualizer;

  /// The Android native equalizer, when this backend runs audio on-device.
  /// Null on non-Android and on remote (cast) backends, where the device's
  /// own audio chain isn't in the path. Surfaced for the EQ screen.
  AndroidEqualizer? get equalizer;

  /// Android audio-session id of the on-device player, for the visualizer's
  /// real-audio capture. Null until a source has loaded, and on remote
  /// backends (no local audio to tap).
  int? get androidAudioSessionId;

  Future<void> dispose();
}
