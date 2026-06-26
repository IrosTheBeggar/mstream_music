import 'dart:math';
import 'dart:typed_data';

/// Produces a smoothed [bandCount]-band magnitude spectrum for the desktop shader
/// visualizer.
///
/// The signal is *synthesized* — the same strategy the Android visualizer uses by
/// default (three drifting carriers across bass/mid/treble + light noise + a 2 Hz
/// beat), so it needs no mic permission and looks alive across the whole spectrum.
/// Each [advance] synthesizes a fresh window, runs a real FFT, and folds the bins
/// into log-spaced bands with fast-attack / slow-decay smoothing. Swapping in real
/// playback PCM later only means replacing [_synth] with captured samples.
class SpectrumSource {
  SpectrumSource({this.bandCount = 64});

  final int bandCount;

  static const int _fftSize = 512; // power of two
  static const double _sampleRate = 44100.0;

  final Random _rng = Random();
  final Float32List _samples = Float32List(_fftSize);

  /// Latest smoothed band magnitudes (0..1), length [bandCount]. Mutated in place
  /// each [advance] so the painter can read it by reference without reallocation.
  late final List<double> bands = List<double>.filled(bandCount, 0.0);

  /// Scales amplitude — louder when something's actually playing, quiet (not dead)
  /// when paused, mirroring the Android source.
  bool playing = true;

  // Carrier phases, kept continuous across frames so the tone doesn't click.
  double _phaseBass = 0, _phaseMid = 0, _phaseTreble = 0;
  int _frame = 0;

  // FFT working buffers.
  final Float64List _re = Float64List(_fftSize);
  final Float64List _im = Float64List(_fftSize);

  /// Synthesize one window, transform it, and update the smoothed [bands].
  void advance() {
    _synth();
    _fft();
    _updateBands();
    _frame++;
  }

  void _synth() {
    final amp = playing ? 0.65 : 0.18;
    const beatHz = 2.0;
    // Sub-1 Hz sweep LFOs evaluated once per window (they barely move across
    // ~12 ms); the carriers then advance by a fixed phase step per sample.
    final tMid = (_frame * _fftSize + _fftSize / 2) / _sampleRate;
    final bassF = 60 + 60 * (0.5 + 0.5 * sin(2 * pi * 0.31 * tMid));
    final midF = 440 + 530 * (0.5 + 0.5 * sin(2 * pi * 0.47 * tMid));
    final trebleF = 2000 + 3000 * (0.5 + 0.5 * sin(2 * pi * 0.71 * tMid));
    final dBass = 2 * pi * bassF / _sampleRate;
    final dMid = 2 * pi * midF / _sampleRate;
    final dTreble = 2 * pi * trebleF / _sampleRate;

    for (var i = 0; i < _fftSize; i++) {
      final t = (_frame * _fftSize + i) / _sampleRate;
      final beat = 0.5 + 0.5 * sin(2 * pi * beatHz * t);
      _phaseBass += dBass;
      _phaseMid += dMid;
      _phaseTreble += dTreble;
      final s = (sin(_phaseBass) * 0.55 +
              sin(_phaseMid) * 0.30 +
              sin(_phaseTreble) * 0.18 +
              (_rng.nextDouble() * 2 - 1) * 0.08) *
          beat *
          amp;
      _samples[i] = s.clamp(-1.0, 1.0).toDouble();
    }
    _phaseBass %= 2 * pi;
    _phaseMid %= 2 * pi;
    _phaseTreble %= 2 * pi;
  }

  void _fft() {
    // Hann window into the FFT buffers (reduces spectral leakage / flicker).
    for (var i = 0; i < _fftSize; i++) {
      final w = 0.5 - 0.5 * cos(2 * pi * i / (_fftSize - 1));
      _re[i] = _samples[i] * w;
      _im[i] = 0.0;
    }
    _transform(_re, _im);
  }

  // In-place iterative radix-2 Cooley–Tukey FFT (n must be a power of two).
  static void _transform(Float64List re, Float64List im) {
    final n = re.length;
    // Bit-reversal permutation.
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        var tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        var ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    // Butterflies.
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * pi / len;
      final wr = cos(ang), wi = sin(ang);
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

  void _updateBands() {
    final bins = _fftSize >> 1; // usable magnitude bins (Nyquist)
    for (var b = 0; b < bandCount; b++) {
      final lo = _binForBand(b, bins);
      final hi = max(lo + 1, _binForBand(b + 1, bins));
      var sum = 0.0;
      var cnt = 0;
      for (var k = lo; k < hi && k < bins; k++) {
        sum += sqrt(_re[k] * _re[k] + _im[k] * _im[k]);
        cnt++;
      }
      var v = cnt > 0 ? sum / cnt : 0.0;
      // Log compression so the quiet synth fills the 0..1 range nicely.
      v = (log(1 + v * 9) / ln10).clamp(0.0, 1.0);
      // Fast attack, slow decay — bars pop up and fall back smoothly.
      final prev = bands[b];
      bands[b] = v > prev ? v : prev * 0.82 + v * 0.18;
    }
  }

  // Log-spaced bin boundary for band [b] (skips DC, which would dominate).
  int _binForBand(int b, int bins) {
    final f = b / bandCount;
    const minBin = 1.0;
    final maxBin = bins.toDouble();
    return (minBin * pow(maxBin / minBin, f)).floor().clamp(1, bins);
  }
}
