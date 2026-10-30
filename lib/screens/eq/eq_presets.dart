// App-defined equalizer presets, mapped onto whatever bands the device
// reports.
//
// Android's own Equalizer presets (usePreset / getPresetName) are not exposed
// by just_audio, so these are the AOSP effect bundle's ten curves, stated at
// that bundle's five centre frequencies (60 / 230 / 910 / 3600 / 14000 Hz) —
// the layout nearly every phone reports, which then gets the exact values the
// system equalizer uses. Any other layout reads its gains off the curve by
// interpolation in log-frequency (how an equalizer spaces its bands), clamped
// to the device's range. Which preset is "selected" is never stored: it is
// whichever curve the live gains spell, so a drag deselects it by itself.

import 'dart:math' as math;

import 'eq_controller.dart' show EqParams;

class EqPreset {
  const EqPreset(this.id, this.curve);

  /// Stable identifier; the screen maps it to a localized name.
  final String id;

  /// (centre frequency in Hz, gain in dB), ascending by frequency.
  final List<(double, double)> curve;

  static EqPreset get flat => kEqPresets.first;

  /// The gain this curve puts at [hz]: linear in log-frequency between the
  /// two nearest points, the end value beyond either end.
  double gainAt(double hz) {
    if (hz <= curve.first.$1) return curve.first.$2;
    if (hz >= curve.last.$1) return curve.last.$2;
    for (var i = 1; i < curve.length; i++) {
      final (f1, g1) = curve[i];
      if (hz <= f1) {
        final (f0, g0) = curve[i - 1];
        final t = (math.log(hz) - math.log(f0)) / (math.log(f1) - math.log(f0));
        return g0 + t * (g1 - g0);
      }
    }
    return curve.last.$2;
  }

  /// One gain per band of [params], clamped to its range, to 0.1 dB.
  List<double> gainsFor(EqParams params) => [
        for (final b in params.bands)
          (gainAt(b.centerFrequency).clamp(params.minDb, params.maxDb) * 10)
                  .roundToDouble() /
              10,
      ];

  /// Whether [gains] (one per band, in band order) are this curve as
  /// [params] reads it, within 0.05 dB.
  bool matches(EqParams params, List<double> gains) {
    final mine = gainsFor(params);
    if (gains.length != mine.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if ((gains[i] - mine[i]).abs() > 0.05) return false;
    }
    return true;
  }
}

/// The preset [gains] spell for [params], or null for a custom curve.
EqPreset? presetFor(EqParams params, List<double> gains) {
  for (final p in kEqPresets) {
    if (p.matches(params, gains)) return p;
  }
  return null;
}

const List<double> _aospHz = [60, 230, 910, 3600, 14000];

EqPreset _aosp(String id, List<double> db) =>
    EqPreset(id, [for (var i = 0; i < _aospHz.length; i++) (_aospHz[i], db[i])]);

/// Flat first (it is also what Reset applies), then the AOSP bundle's order.
final List<EqPreset> kEqPresets = List.unmodifiable([
  _aosp('flat', [0, 0, 0, 0, 0]),
  _aosp('normal', [3, 0, 0, 0, 3]),
  _aosp('classical', [5, 3, -2, 4, 4]),
  _aosp('dance', [6, 0, 2, 4, 1]),
  _aosp('folk', [3, 0, 0, 2, -1]),
  _aosp('heavyMetal', [4, 1, 9, 3, 0]),
  _aosp('hipHop', [5, 3, 0, 1, 3]),
  _aosp('jazz', [4, 2, -2, 2, 5]),
  _aosp('pop', [-1, 2, 5, 1, -2]),
  _aosp('rock', [5, 3, -1, 3, 5]),
]);
