// A text scaler for the strip's tests that is not linear, as Android 14's
// is. Android maps each font size through a table: a small font grows by
// the whole factor and a large one far less, and a font of 100 px or more
// is not scaled at all. Flutter asks the platform for every size it
// scales, so `scale(68)` is not `68 * factor` there.

import 'package:flutter/painting.dart';

/// A scaler shaped like Android 14's non-linear font scaling (AOSP's
/// FontScaleConverterFactory tables): sizes map linearly between the
/// table's points, a 12 px font by the whole factor.
class AndroidFontScale extends TextScaler {
  const AndroidFontScale._(this.factor, this._to);

  /// The system's font size setting: 1.3 is 130 %.
  final double factor;

  final List<double> _to;

  static const List<double> _from = [8, 10, 12, 14, 18, 20, 24, 30, 100];

  /// 130 %: 12 px is drawn at 15.6, but 30 px and 68 px as they are.
  static const AndroidFontScale x13 = AndroidFontScale._(
      1.3, [10.4, 13, 15.6, 18.8, 21.6, 23.6, 26.4, 30, 100]);

  /// 200 %: 12 px is drawn at 24, 30 px at 38 and 68 px at about 72.
  static const AndroidFontScale x20 =
      AndroidFontScale._(2, [16, 20, 24, 26, 30, 34, 36, 38, 100]);

  @override
  double scale(double fontSize) {
    if (fontSize <= _from.first) return fontSize * _to.first / _from.first;
    for (var i = 1; i < _from.length; i++) {
      if (fontSize <= _from[i]) {
        final t = (fontSize - _from[i - 1]) / (_from[i] - _from[i - 1]);
        return _to[i - 1] + t * (_to[i] - _to[i - 1]);
      }
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => factor;

  @override
  String toString() => 'Android ${(factor * 100).round()} %';
}
