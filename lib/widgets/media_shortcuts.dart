// media_shortcuts.dart — desktop keyboard dispatch.
//
// MediaShortcuts wraps the desktop shell, resolves each key-down through the
// user's keymap (util/hotkeys.dart — editable in Settings > Keyboard
// Shortcuts), and runs the matching action against the shared
// AudioPlayerHandler. Shell-level actions (open search, focus the browse
// filter) come in as callbacks since they need shell state.
//
// Crucially it does NOT hijack plain keys while a text field is focused: the
// bare-letter actions (M/S/R/J/L/K) and Space are printable characters, which
// Flutter's shortcut layer would otherwise eat before they reach the search /
// server fields (a focused field does NOT consume printable key-down events at
// the raw-key level). So an unmodified combo no-ops whenever an EditableText
// holds focus, letting every character type normally. Combos WITH a modifier
// (⌘K and friends) stay live — they can't be mistaken for typing.
//
// Volume has no getter on the handler, so the UI volume lives in [playbackVolume]
// — a shared notifier the Now Playing bar's slider and the volume keys both
// read and write, keeping them in sync.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../singletons/media.dart';
import '../util/hotkeys.dart';

/// Current UI playback volume (0.0–1.0). The slider and the keyboard volume keys
/// both drive this; changes are pushed to the backend via [AudioPlayerHandler.setVolume].
final ValueNotifier<double> playbackVolume = ValueNotifier<double>(1.0);

/// How far the volume keys nudge, and how far the seek keys move.
const double _kVolumeStep = 0.05;
const Duration _kSeekStep = Duration(seconds: 10);
const Duration _kBigSeekStep = Duration(seconds: 30);

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

/// Jump to [percent]% of the current track (the 0–9 digit row: 0 = start,
/// 9 = 90%). No-op without a known duration.
void _seekToPercent(int percent) {
  final h = MediaManager().audioHandler;
  final dur = h.mediaItem.value?.duration;
  if (dur == null || dur == Duration.zero) return;
  h.seek(dur * (percent / 10));
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

/// Wraps [child] with the user's keymap (defaults in [kHotkeyDefaults]) plus
/// the hardware media keys, which are fixed — the OS owns those.
class MediaShortcuts extends StatelessWidget {
  final Widget child;

  /// Handlers for the actions the shell owns rather than the player:
  /// [HotkeyAction.openSearch] and [HotkeyAction.localFilter].
  final Map<HotkeyAction, VoidCallback> shellActions;

  const MediaShortcuts(
      {super.key, required this.child, this.shellActions = const {}});

  void _run(HotkeyAction action, KeyEvent event) {
    switch (action) {
      case HotkeyAction.playPause:
      case HotkeyAction.playPauseAlt:
        _togglePlay();
      case HotkeyAction.seekBack:
        _seekBy(-_kSeekStep);
      case HotkeyAction.seekForward:
        _seekBy(_kSeekStep);
      case HotkeyAction.bigSeekBack:
        _seekBy(-_kBigSeekStep);
      case HotkeyAction.bigSeekForward:
        _seekBy(_kBigSeekStep);
      case HotkeyAction.prevTrack:
        _previous();
      case HotkeyAction.nextTrack:
        _next();
      case HotkeyAction.percentSeek:
        final d = HotkeyManager.instance.digitOf(event);
        if (d != null) _seekToPercent(d);
      case HotkeyAction.volumeUp:
        _nudgeVolume(_kVolumeStep);
      case HotkeyAction.volumeDown:
        _nudgeVolume(-_kVolumeStep);
      case HotkeyAction.mute:
        togglePlaybackMute();
      case HotkeyAction.shuffle:
        _toggleShuffle();
      case HotkeyAction.repeat:
        _cycleRepeat();
      case HotkeyAction.openSearch:
      case HotkeyAction.localFilter:
        shellActions[action]?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hardware media keys are not rebindable — the OS delivers them for one
    // purpose each.
    final mediaKeys = <LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.mediaPlayPause: _togglePlay,
      LogicalKeyboardKey.mediaTrackNext: _next,
      LogicalKeyboardKey.mediaTrackPrevious: _previous,
      LogicalKeyboardKey.mediaStop: _stop,
    };
    // autofocus so the shell holds focus (and the shortcuts work) before the
    // user clicks anything; descendant text fields / buttons take focus normally.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final media = mediaKeys[event.logicalKey];
        if (media != null) {
          media();
          return KeyEventResult.handled;
        }
        final action = HotkeyManager.instance.resolve(event);
        if (action == null) return KeyEventResult.ignored;
        // While typing, only modifier combos fire — a bare letter or Space
        // belongs to the text field (see the header).
        final combo = HotkeyManager.instance.bindings[action];
        final isChord = combo != null && (combo.mod || combo.alt);
        if (!isChord && _isEditingText()) return KeyEventResult.ignored;
        _run(action, event);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}

// True when the primary focus is (or is inside) a text field, so the plain
// keys step aside and let the character type.
bool _isEditingText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}
