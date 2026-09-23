import 'dart:math' as math;
import 'dart:typed_data';

/// The audio texture's response curve, the way Android's engine draws it.
///
/// A port of `AudioTexture::upload` in
/// `android/app/src/main/cpp/audio_texture.cpp`, step for step, so a preset
/// reacts on iOS and desktop the way it does on Android — the curve the
/// bundled shaders were retuned against:
///
///  1. the newest [fftSize] samples, Hann-windowed;
///  2. each bin's magnitude normalised to the amplitude of the tone that
///     would make it (2/Σw), so a full-scale sine reads 0 dB whatever the
///     transform's length;
///  3. smoothed in the linear domain, so the bars don't strobe;
///  4. a dB window mapped onto 0..255.
///
/// The waveform row is the newest [bins] samples, -1..1 onto 0..255.
///
/// Arithmetic is rounded to 32-bit float wherever the C++ stores a float, so
/// the bytes come out the way the C++'s do (the FFT itself runs in double).
///
/// One difference, on purpose. Android smooths once per PCM batch — thirty a
/// second, `VisualizerAudio`'s rate — whatever the frame rate. Here the
/// smoothing is by elapsed time, `s^(30·dt)`: exactly Android's step at thirty
/// updates a second, and a 120 Hz screen settles no faster than a 60 Hz one.
///
/// `test/visualizer/spectrum_curve_test.dart` holds this to bytes the C++
/// itself produced (`tool/audio_texture_golden/`).
class SpectrumCurve {
  static const int fftSize = 1024;
  static const int bins = fftSize ~/ 2;

  // audio_texture.h's calibrated defaults.
  static const double defaultMinDb = -69.7;
  static const double defaultMaxDb = -20.7;
  static const double defaultSmoothing = 0.27;

  /// How often Android's smoothing steps, per second.
  static const double _androidRate = 30.0;

  /// The texture, one byte per texel: [bins] of spectrum (row 0), then
  /// [bins] of waveform (row 1). All zero until the first [update], as
  /// Android seeds it.
  final Uint8List bytes = Uint8List(bins * 2);

  final Float32List _window = Float32List(fftSize);
  double _norm = 1.0;
  final Float64List _re = Float64List(fftSize);
  final Float64List _im = Float64List(fftSize);
  final Float32List _smoothed = Float32List(bins);

  double _minDb = _f32(defaultMinDb);
  double _maxDb = _f32(defaultMaxDb);
  double _smoothing = _f32(defaultSmoothing);

  SpectrumCurve() {
    // Symmetric Hann, every step in float and summed in float, as the C++
    // builds it.
    final twoPi = _f32(2.0 * _f32(math.pi));
    var sum = 0.0;
    for (var i = 0; i < fftSize; i++) {
      final angle = _f32(_f32(twoPi * i) / (fftSize - 1));
      _window[i] = _f32(0.5 * _f32(1.0 - _f32(math.cos(angle))));
      sum = _f32(sum + _window[i]);
    }
    _norm = sum > 0 ? _f32(2.0 / sum) : 1.0;
  }

  /// Replace the curve, as Android's `setParams` does: a window with nothing
  /// in it (max at or below min) is refused and the old one kept; smoothing
  /// is held to 0..0.99.
  void setParams({
    required double minDb,
    required double maxDb,
    required double smoothing,
  }) {
    if (maxDb > minDb) {
      _minDb = _f32(minDb);
      _maxDb = _f32(maxDb);
    }
    _smoothing = _f32(smoothing.clamp(0.0, 0.99).toDouble());
  }

  /// The texture for the newest [samples] (mono, oldest first), [dt] seconds
  /// after the last update. Only the tail is read; a history shorter than
  /// the transform counts as silence before it began, which is what
  /// Android's ring holds before it fills.
  void update(List<double> samples, double dt) {
    final take = math.min(samples.length, fftSize);
    final pad = fftSize - take;
    final from = samples.length - take;
    double sample(int i) => i < pad ? 0.0 : samples[from + i - pad];

    for (var i = 0; i < fftSize; i++) {
      _re[i] = _f32(sample(i) * _window[i]);
      _im[i] = 0.0;
    }
    _transform(_re, _im);

    final keep = _f32(math.pow(_smoothing, dt * _androidRate).toDouble());
    final range = _f32(_maxDb - _minDb);
    for (var k = 0; k < bins; k++) {
      final re = _re[k], im = _im[k];
      final magnitude = _f32(_f32(math.sqrt(re * re + im * im)) * _norm);
      final smoothed =
          _f32(_f32(keep * _smoothed[k]) + _f32(_f32(1.0 - keep) * magnitude));
      _smoothed[k] = smoothed;
      final db = _f32(20.0 * _log10(math.max(smoothed, _f32(1e-7))));
      final level = _f32(_f32(db - _minDb) / range).clamp(0.0, 1.0).toDouble();
      bytes[k] = _f32(level * 255.0).truncate();
    }

    for (var x = 0; x < bins; x++) {
      final s = sample(fftSize - bins + x).clamp(-1.0, 1.0).toDouble();
      bytes[bins + x] = _f32(_f32(0.5 + _f32(0.5 * s)) * 255.0).truncate();
    }
  }

  static final Float32List _scratch = Float32List(1);

  /// [value] rounded to the nearest 32-bit float, as a C++ float store does.
  static double _f32(double value) {
    _scratch[0] = value;
    return _scratch[0];
  }

  static double _log10(double value) => _f32(math.log(value) / math.ln10);

  // In-place iterative radix-2 Cooley–Tukey FFT (n must be a power of two).
  static void _transform(Float64List re, Float64List im) {
    final n = re.length;
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang), wi = math.sin(ang);
      final half = len >> 1;
      for (var i = 0; i < n; i += len) {
        var cwr = 1.0, cwi = 0.0;
        for (var k = 0; k < half; k++) {
          final a = i + k, b = a + half;
          final tr = cwr * re[b] - cwi * im[b];
          final ti = cwr * im[b] + cwi * re[b];
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
          final nwr = cwr * wr - cwi * wi;
          cwi = cwr * wi + cwi * wr;
          cwr = nwr;
        }
      }
    }
  }
}
