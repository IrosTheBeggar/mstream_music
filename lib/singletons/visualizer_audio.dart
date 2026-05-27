// Drives the visualizer's audio input. Two strategies — picked by
// [SettingsManager.visualizerAudioSource]:
//
//   * synthesized (default) — generates fake PCM from a low-frequency
//     beat + carrier, modulated by playback state. No permissions, works
//     on every device with the visualizer.
//   * real — captures the actual audio output via an AndroidVisualizer
//     tap. Requires RECORD_AUDIO. NOT IMPLEMENTED YET — falls through
//     to synthesized for now.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../native/visualizer_bridge.dart';
import 'media.dart';
import 'settings.dart';

class VisualizerAudio {
  VisualizerAudio._();
  static final VisualizerAudio _instance = VisualizerAudio._();
  factory VisualizerAudio() => _instance;

  static const _sampleRate = 44100.0;
  static const _samplesPerTick = 512;
  static const _tickHz = 30; // 30 Hz push rate keeps FFT fed without flooding

  Timer? _timer;
  StreamSubscription<bool>? _playbackSub;
  bool _playing = false;
  int _frame = 0;

  void start() {
    if (_timer != null) return;
    _frame = 0;

    // Mirror the actual transport so the visualizer is loud when music
    // is playing and quiet when paused. The visualizer should still
    // render *something* even when paused (a low hum), so it never
    // looks frozen.
    final initial = MediaManager().audioHandler.playbackState.value;
    _playing = initial.playing;
    _playbackSub = MediaManager()
        .audioHandler
        .playbackState
        .map((s) => s.playing)
        .distinct()
        .listen((p) => _playing = p);

    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / _tickHz).round()),
      (_) => _tick(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _playbackSub?.cancel();
    _playbackSub = null;
  }

  void _tick() {
    final samples = _generate();
    VisualizerBridge.addPcm(samples);
  }

  // Interleaved stereo Float32 PCM, in [-1, 1]. The "music" here is a
  // 220 Hz carrier modulated by a 2 Hz beat (120 BPM equivalent), with
  // a touch of low harmonic added so the FFT has something to chew on
  // across bands. Amplitude is scaled to 0.6 when playing, 0.1 when
  // paused — a faint heartbeat keeps the visualizer alive without
  // forcing it to react to dead silence.
  //
  // TODO(real-audio): when SettingsManager().visualizerAudioSource ==
  // VisualizerAudioSource.real, swap this for a live tap of the audio
  // output via AndroidVisualizer. Until that's wired, both modes share
  // the same synthesized output (the dropdown still records the user's
  // pick for when it's available).
  Float32List _generate() {
    final source = SettingsManager().visualizerAudioSource;
    final isReal = source == VisualizerAudioSource.real;

    final amp = _playing ? 0.6 : 0.1;
    final out = Float32List(_samplesPerTick * 2);
    const carrierHz = 220.0;
    const beatHz = 2.0;
    const harmonicHz = 60.0;

    for (var i = 0; i < _samplesPerTick; i++) {
      final t = (_frame * _samplesPerTick + i) / _sampleRate;
      final beat = (sin(2 * pi * beatHz * t) * 0.5 + 0.5); // [0,1]
      final carrier = sin(2 * pi * carrierHz * t);
      final harmonic = sin(2 * pi * harmonicHz * t) * 0.4;
      final s = (carrier + harmonic) * beat * amp;
      // Add a touch of stereo width by phase-shifting the right ear.
      final r = (carrier + harmonic * sin(2 * pi * (harmonicHz + 1) * t))
              * beat * amp;
      out[2 * i] = s.clamp(-1.0, 1.0);
      out[2 * i + 1] = (isReal ? r : s).clamp(-1.0, 1.0);
    }
    _frame++;
    return out;
  }
}
