// The preset curves: the AOSP layout gets the system equalizer's exact
// values, any other layout reads the curve in log-frequency, gains clamp to
// the device's range, the live gains name the preset they spell, and the
// user's saved curves record the device's bands, round-trip through JSON and
// win over a built-in they equal.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/screens/eq/eq_presets.dart';

import 'eq_fakes.dart';

EqPreset byId(String id) => kEqPresets.firstWhere((p) => p.id == id);

void main() {
  test('ten presets, Flat first', () {
    expect(kEqPresets.map((p) => p.id), [
      'flat', 'normal', 'classical', 'dance', 'folk',
      'heavyMetal', 'hipHop', 'jazz', 'pop', 'rock',
    ]);
    expect(EqPreset.flat.id, 'flat');
  });

  test('the AOSP five-band layout gets the system values exactly', () {
    final p = fakeParams();
    expect(byId('flat').gainsFor(p), [0, 0, 0, 0, 0]);
    expect(byId('normal').gainsFor(p), [3, 0, 0, 0, 3]);
    expect(byId('heavyMetal').gainsFor(p), [4, 1, 9, 3, 0]);
    expect(byId('pop').gainsFor(p), [-1, 2, 5, 1, -2]);
    expect(byId('rock').gainsFor(p), [5, 3, -1, 3, 5]);
  });

  test('another layout reads the curve in log-frequency', () {
    final pop = byId('pop');
    // Between 910 Hz (+5) and 3600 Hz (+1): 1810 Hz is the log midpoint.
    expect(pop.gainAt(1810), closeTo(3.0, 0.01));
    // Off either end: the end value.
    expect(pop.gainAt(20), -1);
    expect(pop.gainAt(20000), -2);
    // A ten-band layout: within range, ends pinned, mids interpolated.
    final ten = fakeParams(
        freqs: const [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]);
    final g = pop.gainsFor(ten);
    expect(g, hasLength(10));
    expect(g.first, -1);
    expect(g.last, -2);
    expect(g[5], closeTo(4.8, 0.11), reason: '1 kHz sits just above 910 Hz');
    expect(g.every((x) => x >= -2 && x <= 5), isTrue);
  });

  test('gains clamp to the device range and round to 0.1 dB', () {
    final narrow = fakeParams(minDb: -6, maxDb: 6);
    expect(byId('heavyMetal').gainsFor(narrow), [4, 1, 6, 3, 0]);
    final odd = fakeParams(freqs: const [1000]);
    final g = byId('pop').gainsFor(odd).single;
    expect(g, (g * 10).roundToDouble() / 10);
  });

  test('presetFor names the curve the gains spell, or nothing', () {
    final p = fakeParams();
    expect(presetFor(p, [0, 0, 0, 0, 0])!.id, 'flat');
    expect(presetFor(p, [3, 0, 0, 0, 3])!.id, 'normal',
        reason: 'the device default preset');
    expect(presetFor(p, [3, 0, 0.04, 0, 3])!.id, 'normal',
        reason: 'within 0.05 dB');
    expect(presetFor(p, [3, 0, 0.5, 0, 3]), isNull);
    expect(presetFor(p, [0, 0, 0]), isNull, reason: 'band count differs');
    // On a narrow device the clamped curve is what matches.
    final narrow = fakeParams(minDb: -6, maxDb: 6);
    expect(presetFor(narrow, [4, 1, 6, 3, 0])!.id, 'heavyMetal');
  });

  group('user presets', () {
    test('a saved curve records the device bands to 0.1 dB and maps back exactly',
        () {
      final p = fakeParams(gains: const [1.26, -2.44, 0, 15, -20]);
      final u = EqPreset.user(
          id: 'user:1',
          name: 'Mine',
          params: p,
          gains: [for (final b in p.bands) b.gain]);
      expect(u.isUser, isTrue);
      expect(u.curve.map((c) => c.$1), [60, 230, 910, 3600, 14000]);
      expect(u.curve.map((c) => c.$2), [1.3, -2.4, 0, 15, -15]);
      expect(u.gainsFor(p), [1.3, -2.4, 0, 15, -15]);
      expect(presetFor(p, [1.3, -2.4, 0, 15, -15], user: [u]), same(u));
      // Short gains read as flat for the missing bands.
      expect(EqPreset.user(id: 'u', name: 'n', params: p, gains: const [2])
          .curve.map((c) => c.$2), [2, 0, 0, 0, 0]);
    });

    test('JSON round trip; a malformed entry reads as nothing', () {
      final u = EqPreset('user:7', [(60, 1), (14000, -3)], name: 'Car bass');
      final back = EqPreset.fromJson(json.decode(json.encode(u.toJson())));
      expect(back!.id, 'user:7');
      expect(back.name, 'Car bass');
      expect(back.curve, [(60.0, 1.0), (14000.0, -3.0)]);
      expect(EqPreset.fromJson(null), isNull);
      expect(EqPreset.fromJson('x'), isNull);
      expect(EqPreset.fromJson({'id': 'x'}), isNull);
      expect(EqPreset.fromJson({'id': 'x', 'name': 'y', 'curve': []}), isNull);
      expect(EqPreset.fromJson({'id': 'x', 'name': 'y', 'curve': [[60]]}),
          isNull);
      expect(EqPreset.fromJson({'id': 'x', 'name': 'y', 'curve': [['a', 1]]}),
          isNull);
    });

    test('a saved curve wins over the built-in it equals', () {
      final p = fakeParams();
      final mine = EqPreset.user(
          id: 'user:2', name: 'My rock', params: p, gains: const [5, 3, -1, 3, 5]);
      expect(presetFor(p, [5, 3, -1, 3, 5])!.id, 'rock');
      expect(presetFor(p, [5, 3, -1, 3, 5], user: [mine])!.id, 'user:2');
    });

    test('names compare without case or spaces; a rename keeps the curve',
        () {
      expect(samePresetName(' Car Bass ', 'car bass'), isTrue);
      expect(samePresetName('Car bass', 'Car bass 2'), isFalse);
      final u = EqPreset('user:3', [(60, 1)], name: 'a');
      final r = u.renamed('b');
      expect(r.id, 'user:3');
      expect(r.name, 'b');
      expect(r.curve, u.curve);
      expect(newUserPresetId(), startsWith('user:'));
    });
  });
}
