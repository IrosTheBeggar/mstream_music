// media_shortcuts.dart — standard desktop media-player keyboard shortcuts.
//
// MediaShortcuts wraps the desktop shell and binds the conventional keys to the
// shared AudioPlayerHandler. A focused text field consumes its own keys first
// (Flutter routes the event to the focused node and only bubbles unhandled keys
// up to CallbackShortcuts), so typing in the search / server fields never
// triggers playback control.
//
// Volume has no getter on the handler, so the UI volume lives in [playbackVolume]
// — a shared notifier the Now Playing bar's slider and the Up/Down/Mute keys both
// read and write, keeping them in sync.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../singletons/media.dart';

/// Current UI playback volume (0.0–1.0). The slider and the keyboard volume keys
/// both drive this; changes are pushed to the backend via [AudioPlayerHandler.setVolume].
final ValueNotifier<double> playbackVolume = ValueNotifier<double>(1.0);

/// How far Up/Down nudges the volume, and how far Left/Right seeks.
const double _kVolumeStep = 0.05;
const Duration _kSeekStep = Duration(seconds: 10);

void _togglePlay() {
  final h = MediaManager().audioHandler;
  if (h.playbackState.value.playing) {
    h.pause();
  } else {
    h.play();
  }
}

void _seekBy(Duration delta) {
  final h = MediaManager().audioHandler;
  final dur = h.mediaItem.value?.duration;
  var target = h.position + delta;
  if (target < Duration.zero) target = Duration.zero;
  if (dur != null && target > dur) target = dur;
  h.seek(target);
}

void _next() => MediaManager().audioHandler.skipToNext();
void _previous() => MediaManager().audioHandler.skipToPrevious();
void _stop() => MediaManager().audioHandler.stop();

void _nudgeVolume(double delta) {
  final v = (playbackVolume.value + delta).clamp(0.0, 1.0).toDouble();
  playbackVolume.value = v;
  MediaManager().audioHandler.setVolume(v);
}

// Remembers the level to restore when unmuting.
double _preMuteVolume = 1.0;
void togglePlaybackMute() {
  final h = MediaManager().audioHandler;
  if (playbackVolume.value > 0) {
    _preMuteVolume = playbackVolume.value;
    playbackVolume.value = 0;
    h.setVolume(0);
  } else {
    final restore = _preMuteVolume > 0 ? _preMuteVolume : 1.0;
    playbackVolume.value = restore;
    h.setVolume(restore);
  }
}

void _toggleShuffle() {
  final h = MediaManager().audioHandler;
  final on = h.playbackState.value.shuffleMode == AudioServiceShuffleMode.all;
  h.setShuffleMode(
      on ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all);
}

void _cycleRepeat() {
  final h = MediaManager().audioHandler;
  final mode = h.playbackState.value.repeatMode;
  final next = mode == AudioServiceRepeatMode.none
      ? AudioServiceRepeatMode.all
      : mode == AudioServiceRepeatMode.all
          ? AudioServiceRepeatMode.one
          : AudioServiceRepeatMode.none;
  h.setRepeatMode(next);
}

/// Wraps [child] with the standard media-player key bindings:
///
///   Space            play / pause
///   ← / →            seek −/+ 10s
///   Ctrl/⌘ + ← / →   previous / next track
///   ↑ / ↓            volume up / down
///   M                mute toggle
///   S                shuffle toggle
///   R                repeat cycle
///   media keys       play-pause / next / previous / stop (where the OS delivers them)
class MediaShortcuts extends StatelessWidget {
  final Widget child;
  const MediaShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(_kSeekStep),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(-_kSeekStep),
        // Previous / next — Ctrl on Windows/Linux, ⌘ on macOS.
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _previous,
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            _previous,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _nudgeVolume(_kVolumeStep),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _nudgeVolume(-_kVolumeStep),
        const SingleActivator(LogicalKeyboardKey.keyM): togglePlaybackMute,
        const SingleActivator(LogicalKeyboardKey.keyS): _toggleShuffle,
        const SingleActivator(LogicalKeyboardKey.keyR): _cycleRepeat,
        // Hardware media keys — best-effort (depends on the OS delivering them).
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): _next,
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): _previous,
        const SingleActivator(LogicalKeyboardKey.mediaStop): _stop,
      },
      // A focused node is needed for key events to route here; autofocus makes the
      // shell the default holder so the shortcuts work before the user clicks
      // anything. Descendant text fields / buttons still take focus normally.
      child: Focus(autofocus: true, child: child),
    );
  }
}
