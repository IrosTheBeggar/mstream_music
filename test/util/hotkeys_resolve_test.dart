// Resolution against REAL key events: flutter_test's key simulation drives
// HardwareKeyboard, which is what HotkeyCombo.matches/fromEvent read. Covers
// the paths the unit tests can't (modifier state, digit row, capture).
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/hotkeys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final keys = HotkeyManager.instance;

  setUp(() => keys
    ..restoreDefaults()
    ..enabled = true);

  // Presses [key] (optionally holding the platform mod) and returns the
  // event, the resolved action, and the combo capture would store. All three
  // are computed WHILE the keys are still down: HotkeyCombo reads live
  // HardwareKeyboard state, so both product call sites do the same from
  // inside their key handler.
  Future<(KeyEvent, HotkeyAction?, HotkeyCombo?)> press(LogicalKeyboardKey key,
      {bool mod = false}) async {
    // HotkeyCombo reads dart:io Platform, so the host OS decides which
    // physical modifier counts as `mod` here.
    final modKey = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    if (mod) await simulateKeyDownEvent(modKey);
    KeyEvent? captured;
    void listener(KeyEvent e) => captured ??= e;
    HardwareKeyboard.instance.addHandler((e) {
      listener(e);
      return false;
    });
    await simulateKeyDownEvent(key);
    final action = captured == null ? null : keys.resolve(captured!);
    final combo = captured == null ? null : HotkeyCombo.fromEvent(captured!);
    await simulateKeyUpEvent(key);
    if (mod) await simulateKeyUpEvent(modKey);
    return (captured!, action, combo);
  }

  testWidgets('bare letters resolve to their player actions', (_) async {
    expect((await press(LogicalKeyboardKey.keyM)).$2, HotkeyAction.mute);
    expect((await press(LogicalKeyboardKey.keyS)).$2, HotkeyAction.shuffle);
    expect((await press(LogicalKeyboardKey.keyR)).$2, HotkeyAction.repeat);
    expect((await press(LogicalKeyboardKey.space)).$2, HotkeyAction.playPause);
  });

  testWidgets('the mod chord resolves, and the same key alone does not',
      (_) async {
    expect((await press(LogicalKeyboardKey.keyK, mod: true)).$2,
        HotkeyAction.openSearch);
    // Bare K is the alternate play/pause, NOT search — the modifier is part
    // of the binding's identity.
    expect((await press(LogicalKeyboardKey.keyK)).$2,
        HotkeyAction.playPauseAlt);
  });

  testWidgets('arrows seek bare and skip tracks with the mod', (_) async {
    expect((await press(LogicalKeyboardKey.arrowRight)).$2,
        HotkeyAction.seekForward);
    expect((await press(LogicalKeyboardKey.arrowRight, mod: true)).$2,
        HotkeyAction.nextTrack);
  });

  testWidgets('the whole digit row drives percentSeek', (_) async {
    final digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit9,
    ];
    for (final d in digits) {
      final (event, action, _) = await press(d);
      expect(action, HotkeyAction.percentSeek, reason: d.keyLabel);
      expect(keys.digitOf(event), isNotNull);
    }
    // Unbinding the sentinel frees the digits entirely.
    keys.assign(HotkeyAction.percentSeek, null);
    expect((await press(LogicalKeyboardKey.digit5)).$2, isNull);
  });

  testWidgets('unbound keys stay unclaimed', (_) async {
    expect((await press(LogicalKeyboardKey.keyQ)).$2, isNull);
    keys.assign(HotkeyAction.mute, null);
    expect((await press(LogicalKeyboardKey.keyM)).$2, isNull);
  });

  testWidgets('a rebind takes effect, and the master toggle silences all',
      (_) async {
    keys.assign(HotkeyAction.mute, HotkeyCombo(LogicalKeyboardKey.keyQ.keyId));
    expect((await press(LogicalKeyboardKey.keyQ)).$2, HotkeyAction.mute);
    expect((await press(LogicalKeyboardKey.keyM)).$2, isNull);

    keys.enabled = false;
    expect((await press(LogicalKeyboardKey.keyQ)).$2, isNull);
    expect((await press(LogicalKeyboardKey.space)).$2, isNull);
  });

  testWidgets('capture builds the combo the editor stores', (_) async {
    final (_, _, combo) = await press(LogicalKeyboardKey.keyQ, mod: true);
    expect(combo, isNotNull);
    expect(combo!.keyId, LogicalKeyboardKey.keyQ.keyId);
    expect(combo.mod, isTrue);
    // Round-trips through storage unchanged.
    expect(HotkeyCombo.decode(combo.encode()), equals(combo));
  });

  testWidgets('capture refuses Escape and bare modifiers', (_) async {
    expect((await press(LogicalKeyboardKey.escape)).$3, isNull);
    expect((await press(LogicalKeyboardKey.shiftLeft)).$3, isNull);
  });
}
