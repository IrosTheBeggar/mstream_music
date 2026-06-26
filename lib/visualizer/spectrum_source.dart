import 'dart:math';
import 'dart:typed_data';

/// Produces the Shadertoy-style audio texture (`iChannel0`) the desktop shader
/// visualizer samples: an RGBA image, [texWidth]×[texHeight] (512×2), where
///   row 0 = FFT magnitude spectrum (linear bins, 0..22 kHz)
///   row 1 = the time-domain waveform (centred at 0.5)
/// matching the native AudioTexture's layout, so the ported shaders read it with
/// `texture(iChannel0, vec2(freq, 0.25))` / `vec2(t, 0.75)` unchanged.
///
/// The signal is synthesized — the same strategy the Android visualizer uses by
/// default (three drifting carriers across bass/mid/treble + light noise + a 2 Hz
/// beat), so it needs no mic permission and looks alive across the spectrum.
/// Replacing [_synth] with captured playback PCM later is all that real-audio
/// reactivity needs.
class SpectrumSource {
  static const int _fftSize = 1024; // → 512 magnitude bins
  static const int bins = _fftSize ~/ 2; // 512
  static const int texWidth = bins; // 512
  static const int texHeight = 2;
  static const double _sampleRate = 44100.0;

  final Random _rng = Random();
  final Float32List _samples = Float32List(_fftSize);

  /// RGBA8888 pixel buffer (row-major, [texWidth]×[texHeight]), refreshed each
  /// [advance]. Handed to `decodeImageFromPixels` to build the sampler image.
  final Uint8List textureBytes = Uint8List(texWidth * texHeight * 4);

  /// Amplitude follows playback: full when playing, quiet (not dead) when paused.
  bool playing = true;

  double _phaseBass = 0, _phaseMid = 0, _phaseTreble = 0;
  int _frame = 0;

  final Float64List _re = Float64List(_fftSize);
  final Float64List _im = Float64List(_fftSize);

  /// Synthesize a window, FFT it, and refresh [textureBytes].
  void advance() {
    _synth();
    _fft();
    _writeTexture();
    _frame++;
  }

  void _synth() {
    final amp = playing ? 0.65 : 0.18;
    const beatHz = 2.0;
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
    for (var i = 0; i < _fftSize; i++) {
      final w = 0.5 - 0.5 * cos(2 * pi * i / (_fftSize - 1)); // Hann
      _re[i] = _samples[i] * w;
      _im[i] = 0.0;
    }
    _transform(_re, _im);
  }

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
        var tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        var ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
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

  void _writeTexture() {
    // Normalize a Hann-windowed magnitude (a pure tone peaks near fftSize/4) and
    // perceptually spread it with sqrt so quiet content still shows.
    const norm = 1.0 / (_fftSize * 0.25);
    for (var x = 0; x < bins; x++) {
      final mag = sqrt(_re[x] * _re[x] + _im[x] * _im[x]) * norm;
      final v = (sqrt(mag.clamp(0.0, 1.0)) * 255).round();
      final o = x * 4; // row 0
      textureBytes[o] = v;
      textureBytes[o + 1] = v;
      textureBytes[o + 2] = v;
      textureBytes[o + 3] = 255;

      final w = ((0.5 + 0.5 * _samples[x]).clamp(0.0, 1.0) * 255).round();
      final o2 = (bins + x) * 4; // row 1
      textureBytes[o2] = w;
      textureBytes[o2 + 1] = w;
      textureBytes[o2 + 2] = w;
      textureBytes[o2 + 3] = 255;
    }
  }
}
