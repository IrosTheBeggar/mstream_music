import 'dart:math';
import 'dart:typed_data';

import '../native/audio_capture.dart';
import '../native/viz_decoder.dart';
import 'spectrum_curve.dart';

/// Produces the Shadertoy-style audio texture (`iChannel0`) the desktop shader
/// visualizer samples: an RGBA image, [texWidth]×[texHeight] (512×2), where
///   row 0 = FFT magnitude spectrum (linear bins, 0..22 kHz)
///   row 1 = the time-domain waveform (centred at 0.5)
/// matching the native AudioTexture's layout, so the ported shaders read it with
/// `texture(iChannel0, vec2(freq, 0.25))` / `vec2(t, 0.75)` unchanged.
///
/// The samples are the real playback signal where there is one — the decode
/// sidecar (iOS, macOS) or the loopback capture (Windows) — and otherwise the
/// synthesized signal the Android visualizer also falls back on. Either way the
/// bytes come from [SpectrumCurve], Android's own response curve, so a preset
/// reacts here the way it does on a phone.
class SpectrumSource {
  static const int _fftSize = SpectrumCurve.fftSize; // → 512 magnitude bins
  static const int bins = SpectrumCurve.bins; // 512
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

  /// Current playback position provider (ms), set by the screen. Keys the
  /// playback-decode path ([VizDecoder]) to what the listener actually hears;
  /// null (or an idle decoder) keeps the capture/synth behavior unchanged.
  int Function()? positionMs;

  double _phaseBass = 0, _phaseMid = 0, _phaseTreble = 0;
  int _frame = 0;

  final SpectrumCurve _curve = SpectrumCurve();

  /// Fill a window (real playback PCM if captured, else synthesized), run it
  /// through the curve, and refresh [textureBytes]. [dt] is the seconds since
  /// the last call: the curve smooths by time, not by frame.
  void advance(double dt) {
    if (!_readReal()) _synth();
    _curve.update(_samples, dt);
    _writeTexture();
    _frame++;
  }

  /// Pull real playback samples into [_samples], preferring the decode
  /// sidecar (iOS: the window ending at the playback position) over the
  /// desktop WASAPI loopback capture. Returns false — so [advance] falls back
  /// to [_synth] — until a source holds a full window (sidecar priming /
  /// scrubs, the capture ring's first ~20 ms) and on platforms / states with
  /// neither. Silence reads back as a full window of zeros, which the FFT
  /// turns into a calm (not frozen) display.
  bool _readReal() {
    final dec = VizDecoder.instance;
    final pos = positionMs;
    if (dec.isRunning && pos != null) {
      if (dec.read(_samples, _fftSize, pos()) >= _fftSize) return true;
      // Not buffered yet (or just died): synth for this frame; a dead session
      // stays quiet (isRunning flips false) instead of re-asking every frame.
      return false;
    }
    final cap = AudioCapture.instance;
    if (!cap.isRunning) return false;
    return cap.read(_samples, _fftSize) >= _fftSize;
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

  // The curve's one byte per texel, as the RGBA the sampler image is built
  // from: the value in R, G and B, opaque.
  void _writeTexture() {
    final bytes = _curve.bytes;
    for (var i = 0; i < bytes.length; i++) {
      final v = bytes[i];
      final o = i * 4;
      textureBytes[o] = v;
      textureBytes[o + 1] = v;
      textureBytes[o + 2] = v;
      textureBytes[o + 3] = 255;
    }
  }
}
