import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/hotkeys.dart';

void main() {
  group('HotkeyCombo encoding', () {
    test('round-trips every default binding', () {
      for (final entry in kHotkeyDefaults.entries) {
        final combo = entry.value;
        if (combo == null) continue;
        final decoded = HotkeyCombo.decode(combo.encode());
        expect(decoded, isNotNull, reason: '${entry.key.name} failed to decode');
        expect(decoded, equals(combo), reason: '${entry.key.name} changed');
        expect(decoded!.keyId, combo.keyId);
        expect(decoded.mod, combo.mod);
      }
    });

    test('decodes modifier prefixes and rejects junk', () {
      final c = HotkeyCombo.decode('mod+alt+0x6b')!;
      expect(c.keyId, LogicalKeyboardKey.keyK.keyId);
      expect(c.mod, isTrue);
      expect(c.alt, isTrue);
      expect(HotkeyCombo.decode(null), isNull);
      expect(HotkeyCombo.decode(''), isNull);
      expect(HotkeyCombo.decode('mod+notakey'), isNull);
    });

    test('labels read as keycaps', () {
      expect(kHotkeyDefaults[HotkeyAction.playPause]!.label, 'Space');
      expect(kHotkeyDefaults[HotkeyAction.seekForward]!.label, '→');
      expect(kHotkeyDefaults[HotkeyAction.mute]!.label, 'M');
      // The mod glyph is platform-specific; the key part is not.
      expect(kHotkeyDefaults[HotkeyAction.openSearch]!.label, endsWith('K'));
      expect(kHotkeyDefaults[HotkeyAction.openSearch]!.label, contains('+'));
    });

    test('shift is part of identity only for non-printable keys', () {
      final printable = HotkeyCombo(LogicalKeyboardKey.keyM.keyId);
      final printableShifted =
          HotkeyCombo(LogicalKeyboardKey.keyM.keyId, shift: true);
      expect(printable, equals(printableShifted));

      final named = HotkeyCombo(LogicalKeyboardKey.arrowUp.keyId);
      final namedShifted =
          HotkeyCombo(LogicalKeyboardKey.arrowUp.keyId, shift: true);
      expect(named, isNot(equals(namedShifted)));
      // A shifted named key keeps its shift through a save/load cycle.
      expect(HotkeyCombo.decode(namedShifted.encode())!.shift, isTrue);
    });
  });

  group('HotkeyManager bindings', () {
    setUp(() => HotkeyManager.instance
      ..restoreDefaults()
      ..enabled = true);

    test('assigning a taken combo unbinds the previous holder', () {
      final keys = HotkeyManager.instance;
      final muteCombo = keys.bindings[HotkeyAction.mute]!;
      keys.assign(HotkeyAction.shuffle, muteCombo);
      expect(keys.bindings[HotkeyAction.shuffle], equals(muteCombo));
      expect(keys.bindings[HotkeyAction.mute], isNull,
          reason: 'the stolen-from action must go unbound');
    });

    test('assigning null unbinds without touching others', () {
      final keys = HotkeyManager.instance;
      keys.assign(HotkeyAction.repeat, null);
      expect(keys.bindings[HotkeyAction.repeat], isNull);
      expect(keys.bindings[HotkeyAction.mute],
          equals(kHotkeyDefaults[HotkeyAction.mute]));
    });

    test('restoreDefaults undoes every edit', () {
      final keys = HotkeyManager.instance;
      keys.assign(HotkeyAction.mute, null);
      keys.assign(HotkeyAction.shuffle, HotkeyCombo(LogicalKeyboardKey.f9.keyId));
      keys.restoreDefaults();
      expect(keys.bindings, equals(kHotkeyDefaults));
    });
  });

  group('HotkeyManager persistence', () {
    setUp(() => HotkeyManager.instance
      ..restoreDefaults()
      ..enabled = true);

    test('saved bindings survive a load round-trip', () {
      final keys = HotkeyManager.instance;
      keys.assign(HotkeyAction.mute, HotkeyCombo(LogicalKeyboardKey.f9.keyId));
      keys.assign(HotkeyAction.repeat, null);
      final saved = keys.toJson();

      keys.restoreDefaults();
      keys.loadFrom(saved);

      expect(keys.bindings[HotkeyAction.mute]!.keyId,
          LogicalKeyboardKey.f9.keyId);
      expect(keys.bindings[HotkeyAction.repeat], isNull);
      expect(keys.bindings[HotkeyAction.playPause],
          equals(kHotkeyDefaults[HotkeyAction.playPause]));
    });

    test('a stored file missing an action keeps that action default', () {
      final keys = HotkeyManager.instance;
      // Simulates upgrading into a build that added new actions.
      keys.loadFrom({'mute': null});
      expect(keys.bindings[HotkeyAction.mute], isNull);
      expect(keys.bindings[HotkeyAction.openSearch],
          equals(kHotkeyDefaults[HotkeyAction.openSearch]));
      expect(keys.bindings.length, HotkeyAction.values.length);
    });

    test('unknown / malformed stored entries are dropped, not fatal', () {
      final keys = HotkeyManager.instance;
      keys.loadFrom({'someRemovedAction': 'mod+0x61', 'shuffle': 12345});
      expect(keys.bindings.containsKey(HotkeyAction.shuffle), isTrue);
      expect(keys.bindings[HotkeyAction.shuffle], isNull,
          reason: 'a non-string value reads as unbound');
      expect(keys.bindings.length, HotkeyAction.values.length);
    });

    test('null stored map yields pure defaults', () {
      final keys = HotkeyManager.instance;
      keys.loadFrom(null, enabled: false);
      expect(keys.bindings, equals(kHotkeyDefaults));
      expect(keys.enabled, isFalse);
    });
  });

  group('defaults sanity', () {
    test('no two actions share a combo', () {
      final seen = <HotkeyCombo, HotkeyAction>{};
      for (final e in kHotkeyDefaults.entries) {
        // percentSeek's stored combo is a sentinel for the whole digit row.
        if (e.key == HotkeyAction.percentSeek || e.value == null) continue;
        expect(seen.containsKey(e.value), isFalse,
            reason: '${e.key.name} collides with ${seen[e.value]?.name}');
        seen[e.value!] = e.key;
      }
    });

    test('every action has a default and an editor label', () {
      for (final a in HotkeyAction.values) {
        expect(kHotkeyDefaults.containsKey(a), isTrue,
            reason: '${a.name} has no default binding');
      }
    });
  });
}
