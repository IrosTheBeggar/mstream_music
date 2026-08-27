// hotkeys.dart — the desktop keymap: actions, default bindings, persistence,
// and event→action resolution.
//
// Mirrors the web player's configurable keymap (MSTREAMPLAYER.hotkeys +
// the Keyboard Shortcuts modal): one combo maps to one action, bindings
// persist and are merged over the defaults on load — so a new action picks
// up its default automatically and a stale one is dropped — and a master
// toggle disables the lot. The editor lives in screens/hotkeys_dialog.dart;
// dispatch lives in widgets/media_shortcuts.dart.
//
// A combo is a key plus modifier flags. `mod` is the platform's primary
// modifier: ⌘ on macOS (where Ctrl also matches, preserving the app's
// original dual Ctrl/⌘ binding), Ctrl on Windows/Linux. Shift is inherent
// to typing printable characters, so it is ignored for single-character
// keys but honoured for named keys (Shift+→ stays free for text selection).

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Every rebindable action, in the order the editor lists them.
enum HotkeyAction {
  playPause,
  playPauseAlt,
  seekBack,
  seekForward,
  bigSeekBack,
  bigSeekForward,
  prevTrack,
  nextTrack,
  percentSeek,
  volumeUp,
  volumeDown,
  mute,
  shuffle,
  repeat,
  openSearch,
  localFilter,
}

/// A key + modifiers. Serialized as `mod+alt+shift+<keyId hex>`.
class HotkeyCombo {
  final int keyId;
  final bool mod;
  final bool alt;
  final bool shift;

  const HotkeyCombo(this.keyId,
      {this.mod = false, this.alt = false, this.shift = false});

  /// True when this combo's key produces a printable character — the class
  /// of key that would otherwise be typing (Space included). Shift is
  /// ignored for these: '<' IS Shift+comma, so demanding an exact shift
  /// match would make such a binding unreachable.
  bool get isPrintable {
    if (keyId == LogicalKeyboardKey.space.keyId) return true;
    final k = LogicalKeyboardKey.findKeyByKeyId(keyId);
    return (k?.keyLabel ?? '').trim().length == 1;
  }

  String encode() => [
        if (mod) 'mod',
        if (alt) 'alt',
        if (shift && !isPrintable) 'shift',
        '0x${keyId.toRadixString(16)}',
      ].join('+');

  static HotkeyCombo? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('+');
    final keyId = int.tryParse(parts.last);
    if (keyId == null) return null;
    return HotkeyCombo(keyId,
        mod: parts.contains('mod'),
        alt: parts.contains('alt'),
        shift: parts.contains('shift'));
  }

  /// Build a combo from a key-down event, or null when the event can't be
  /// bound (a bare modifier press, or Escape which the editor uses to
  /// cancel).
  ///
  /// Reads live [HardwareKeyboard] state for the modifiers, so it — like
  /// [matches] — MUST be called synchronously from the key handler. Defer it
  /// past the key-up and the modifiers are already gone.
  static HotkeyCombo? fromEvent(KeyEvent e) {
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) return null;
    final modifiers = {
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    };
    if (modifiers.contains(k)) return null;
    final hw = HardwareKeyboard.instance;
    return HotkeyCombo(k.keyId,
        mod: _modHeld(hw), alt: hw.isAltPressed, shift: hw.isShiftPressed);
  }

  static bool _modHeld(HardwareKeyboard hw) => Platform.isMacOS
      // macOS: ⌘ is primary, but Ctrl matches too — the app's original
      // bindings accepted either for prev/next and users have both habits.
      ? (hw.isMetaPressed || hw.isControlPressed)
      : hw.isControlPressed;

  bool matches(KeyEvent e) {
    if (e.logicalKey.keyId != keyId) return false;
    final hw = HardwareKeyboard.instance;
    if (_modHeld(hw) != mod) return false;
    if (hw.isAltPressed != alt) return false;
    // Shift is part of typing '<' or '?', so a printable key ignores it; a
    // named key (arrows, space) must match exactly so Shift+→ still selects.
    if (!isPrintable && hw.isShiftPressed != shift) return false;
    // A non-mac Win/Cmd press is never ours.
    if (!Platform.isMacOS && hw.isMetaPressed) return false;
    return true;
  }

  /// Human-readable form for the editor: "⌘ K", "Space", "→".
  String get label {
    final modLabel = Platform.isMacOS ? '⌘' : 'Ctrl';
    final altLabel = Platform.isMacOS ? '⌥' : 'Alt';
    return [
      if (mod) modLabel,
      if (alt) altLabel,
      if (shift && !isPrintable) Platform.isMacOS ? '⇧' : 'Shift',
      _labelOf(keyId),
    ].join(' + ');
  }

  @override
  bool operator ==(Object other) =>
      other is HotkeyCombo &&
      other.keyId == keyId &&
      other.mod == mod &&
      other.alt == alt &&
      (other.shift == shift || isPrintable);

  @override
  int get hashCode => Object.hash(keyId, mod, alt, isPrintable ? false : shift);
}

// Display names for keys whose keyLabel is empty or unhelpful. Keyed off
// the constants themselves so a Flutter keyId change can't silently
// mislabel a row.
final Map<int, String> _keyNames = {
  LogicalKeyboardKey.space.keyId: 'Space',
  LogicalKeyboardKey.arrowLeft.keyId: '←',
  LogicalKeyboardKey.arrowRight.keyId: '→',
  LogicalKeyboardKey.arrowUp.keyId: '↑',
  LogicalKeyboardKey.arrowDown.keyId: '↓',
  LogicalKeyboardKey.enter.keyId: 'Enter',
  LogicalKeyboardKey.tab.keyId: 'Tab',
};

String _labelOf(int keyId) {
  final named = _keyNames[keyId];
  if (named != null) return named;
  final k = LogicalKeyboardKey.findKeyByKeyId(keyId);
  final l = k?.keyLabel ?? '';
  if (l.isNotEmpty) return l.length == 1 ? l.toUpperCase() : l;
  return '0x${keyId.toRadixString(16)}';
}

/// Factory defaults — the bindings the desktop shipped with, plus the web
/// player's J/L big seeks, K alternate play/pause, and the 0–9 percent jump.
final Map<HotkeyAction, HotkeyCombo?> kHotkeyDefaults = {
  HotkeyAction.playPause: HotkeyCombo(LogicalKeyboardKey.space.keyId),
  HotkeyAction.playPauseAlt: HotkeyCombo(LogicalKeyboardKey.keyK.keyId),
  HotkeyAction.seekBack: HotkeyCombo(LogicalKeyboardKey.arrowLeft.keyId),
  HotkeyAction.seekForward: HotkeyCombo(LogicalKeyboardKey.arrowRight.keyId),
  HotkeyAction.bigSeekBack: HotkeyCombo(LogicalKeyboardKey.keyJ.keyId),
  HotkeyAction.bigSeekForward: HotkeyCombo(LogicalKeyboardKey.keyL.keyId),
  HotkeyAction.prevTrack:
      HotkeyCombo(LogicalKeyboardKey.arrowLeft.keyId, mod: true),
  HotkeyAction.nextTrack:
      HotkeyCombo(LogicalKeyboardKey.arrowRight.keyId, mod: true),
  // Sentinel: the digit row is one action, not ten bindings (see
  // HotkeyManager.resolve). Only clear/restore applies to it.
  HotkeyAction.percentSeek: HotkeyCombo(LogicalKeyboardKey.digit0.keyId),
  HotkeyAction.volumeUp: HotkeyCombo(LogicalKeyboardKey.arrowUp.keyId),
  HotkeyAction.volumeDown: HotkeyCombo(LogicalKeyboardKey.arrowDown.keyId),
  HotkeyAction.mute: HotkeyCombo(LogicalKeyboardKey.keyM.keyId),
  HotkeyAction.shuffle: HotkeyCombo(LogicalKeyboardKey.keyS.keyId),
  HotkeyAction.repeat: HotkeyCombo(LogicalKeyboardKey.keyR.keyId),
  HotkeyAction.openSearch:
      HotkeyCombo(LogicalKeyboardKey.keyK.keyId, mod: true),
  HotkeyAction.localFilter:
      HotkeyCombo(LogicalKeyboardKey.keyF.keyId, mod: true),
};

/// Live keymap: current bindings, persistence hooks, and the resolver the
/// key handler calls. Owned by SettingsManager (which does the file I/O);
/// this holds the in-memory map and the matching logic.
class HotkeyManager {
  HotkeyManager._();
  static final HotkeyManager instance = HotkeyManager._();

  bool enabled = true;
  final Map<HotkeyAction, HotkeyCombo?> bindings = {...kHotkeyDefaults};

  /// Merge stored bindings over the defaults. Unknown action names are
  /// dropped; a missing one keeps its default; an explicit null stays
  /// unbound.
  void loadFrom(Map<String, dynamic>? stored, {bool enabled = true}) {
    this.enabled = enabled;
    bindings
      ..clear()
      ..addAll(kHotkeyDefaults);
    if (stored == null) return;
    for (final a in HotkeyAction.values) {
      if (!stored.containsKey(a.name)) continue;
      final raw = stored[a.name];
      bindings[a] = raw is String ? HotkeyCombo.decode(raw) : null;
    }
  }

  Map<String, dynamic> toJson() =>
      {for (final e in bindings.entries) e.key.name: e.value?.encode()};

  /// The action bound to [e], or null when the key is unclaimed. Digits
  /// resolve to [HotkeyAction.percentSeek] while that action is bound —
  /// the whole 0–9 row, matching the web player.
  HotkeyAction? resolve(KeyEvent e) {
    if (!enabled) return null;
    for (final entry in bindings.entries) {
      if (entry.key == HotkeyAction.percentSeek) continue;
      if (entry.value?.matches(e) ?? false) return entry.key;
    }
    if (bindings[HotkeyAction.percentSeek] != null && _isPlainDigit(e)) {
      return HotkeyAction.percentSeek;
    }
    return null;
  }

  /// 0–9 for the percent jump: digit row only, no modifiers.
  bool _isPlainDigit(KeyEvent e) {
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed) {
      return false;
    }
    return digitOf(e) != null;
  }

  /// The digit 0–9 this event carries, or null.
  int? digitOf(KeyEvent e) {
    final digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final i = digits.indexOf(e.logicalKey);
    return i < 0 ? null : i;
  }

  /// Bind [action] to [combo] (null unbinds). One combo maps to one action:
  /// stealing a combo leaves the previous holder unbound, as in the web
  /// player's modal.
  void assign(HotkeyAction action, HotkeyCombo? combo) {
    if (combo != null) {
      for (final other in bindings.keys.toList()) {
        if (other != action &&
            other != HotkeyAction.percentSeek &&
            bindings[other] == combo) {
          bindings[other] = null;
        }
      }
    }
    bindings[action] = combo;
  }

  void restoreDefaults() {
    bindings
      ..clear()
      ..addAll(kHotkeyDefaults);
  }
}
