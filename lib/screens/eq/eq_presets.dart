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
//
// The user's own presets work the same way: a saved curve is the live gains
// recorded at this device's band frequencies (to 0.1 dB), so it maps back
// exactly here and by interpolation on any other layout. They persist as
// JSON in settings and are checked before the built-ins, so a curve the user
// named wins over a built-in it happens to equal.

import 'dart:math' as math;

import 'eq_controller.dart' show EqParams;

class EqPreset {
  const EqPreset(this.id, this.curve, {this.name});

  /// Stable identifier; the screen maps a built-in's to a localized name.
  final String id;

  /// (centre frequency in Hz, gain in dB), ascending by frequency.
  final List<(double, double)> curve;

  /// The user's own name for a saved curve; null for a built-in.
  final String? name;

  bool get isUser => name != null;

  static EqPreset get flat => kEqPresets.first;

  /// A saved curve: [gains] (one per band of [params], in band order) at the
  /// device's own frequencies, clamped to its range and rounded to 0.1 dB.
  factory EqPreset.user({
    required String id,
    required String name,
    required EqParams params,
    required List<double> gains,
  }) =>
      EqPreset(id, [
        for (var i = 0; i < params.bands.length; i++)
          (
            params.bands[i].centerFrequency,
            ((i < gains.length ? gains[i] : 0.0)
                        .clamp(params.minDb, params.maxDb) *
                    10)
                .roundToDouble() /
                10,
          ),
      ], name: name);

  /// The same curve under another name.
  EqPreset renamed(String name) => EqPreset(id, curve, name: name);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'curve': [
          for (final (f, g) in curve) [f, g],
        ],
      };

  /// A saved preset back from [toJson]'s shape; null for anything malformed,
  /// so one bad entry in settings drops that entry, not the list.
  static EqPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final curve = raw['curve'];
    if (id is! String || name is! String || curve is! List) return null;
    final points = <(double, double)>[];
    for (final e in curve) {
      if (e is! List || e.length != 2) return null;
      final f = e[0];
      final g = e[1];
      if (f is! num || g is! num) return null;
      points.add((f.toDouble(), g.toDouble()));
    }
    if (points.isEmpty) return null;
    return EqPreset(id, points, name: name);
  }

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

  /// One gain per centre frequency in [freqs], clamped to the range, to
  /// 0.1 dB.
  List<double> gainsForLayout(
          List<double> freqs, double minDb, double maxDb) =>
      [
        for (final f in freqs)
          (gainAt(f).clamp(minDb, maxDb) * 10).roundToDouble() / 10,
      ];

  /// One gain per band of [params], clamped to its range, to 0.1 dB.
  List<double> gainsFor(EqParams params) => gainsForLayout(
      [for (final b in params.bands) b.centerFrequency],
      params.minDb,
      params.maxDb);

  /// Whether [gains] (one per band, in band order) are this curve as the
  /// layout reads it, within 0.05 dB.
  bool matchesLayout(
      List<double> freqs, double minDb, double maxDb, List<double> gains) {
    final mine = gainsForLayout(freqs, minDb, maxDb);
    if (gains.length != mine.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if ((gains[i] - mine[i]).abs() > 0.05) return false;
    }
    return true;
  }

  bool matches(EqParams params, List<double> gains) => matchesLayout(
      [for (final b in params.bands) b.centerFrequency],
      params.minDb,
      params.maxDb,
      gains);
}

/// The preset [gains] spell for a layout, or null for a custom curve. The
/// user's saved curves ([user]) are checked before the built-ins.
EqPreset? presetForLayout(
    List<double> freqs, double minDb, double maxDb, List<double> gains,
    {List<EqPreset> user = const []}) {
  for (final p in user.followedBy(kEqPresets)) {
    if (p.matchesLayout(freqs, minDb, maxDb, gains)) return p;
  }
  return null;
}

/// The preset [gains] spell for [params], or null for a custom curve.
EqPreset? presetFor(EqParams params, List<double> gains,
        {List<EqPreset> user = const []}) =>
    presetForLayout([for (final b in params.bands) b.centerFrequency],
        params.minDb, params.maxDb, gains,
        user: user);

/// Whether two preset names are the same name: case and surrounding spaces
/// do not make a different preset.
bool samePresetName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// A fresh id for a saved preset.
String newUserPresetId() =>
    'user:${DateTime.now().microsecondsSinceEpoch}';

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
