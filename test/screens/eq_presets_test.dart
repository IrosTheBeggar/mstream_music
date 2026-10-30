// The preset curves: the AOSP layout gets the system equalizer's exact
// values, any other layout reads the curve in log-frequency, gains clamp to
// the device's range, and the live gains name the preset they spell.

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
}
