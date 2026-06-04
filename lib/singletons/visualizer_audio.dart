// Drives the visualizer's audio input. Two strategies — picked by
// [SettingsManager.visualizerAudioSource]:
//
//   * synthesized (default) — generates broadband PCM from a few
//     overlapping sweeps + low-amplitude pink-ish noise + a 2 Hz
//     beat envelope. No permissions, works everywhere; designed so
//     the spectrum analyzer shaders look populated across the whole
//     frequency range even when nothing's playing.
//   * real — taps the OS audio output via android.media.audiofx.
//     Visualizer on session 0. Requires RECORD_AUDIO. Falls back to
//     synthesized if the OS refuses the capture (revoked permission,
//     session 0 locked down by the device, etc.).

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
  static const _tickHz = 30;

  Timer? _timer;
  StreamSubscription<bool>? _playbackSub;
  bool _playing = false;
  int _frame = 0;
  bool _realAttached = false;
  bool _active = false;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    _frame = 0;

    final initial = MediaManager().audioHandler.playbackState.value;
    _playing = initial.playing;
    _playbackSub = MediaManager()
        .audioHandler
        .playbackState
        .map((s) => s.playing)
        .distinct()
        .listen((p) => _playing = p);

    // If the user opted into real audio AND we can actually attach
    // the Visualizer, hand off to Kotlin entirely — no need for the
    // synthesized timer. If Visualizer attach fails (permission
    // revoked or OS quirk), silently fall back to synthesized so
    // the user still sees something.
    if (SettingsManager().visualizerAudioSource == VisualizerAudioSource.real) {
      // Attach the Visualizer to THIS app's own audio session, not the
      // global mix (session 0), which modern Android blocks. The session
      // id is null until the player has loaded a source, so real audio
      // only attaches once something has been played.
      final sessionId = MediaManager().audioHandler.androidAudioSessionId;
      if (sessionId != null) {
        final ok = await VisualizerBridge.startRealAudio(sessionId);
        if (ok) {
          _realAttached = true;
          return;
        }
      }
      // ignore: avoid_print
      print('VisualizerAudio: real-audio attach failed '
          '(sessionId=$sessionId); using synthesized');
    }

    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / _tickHz).round()),
      (_) => _tick(),
    );
  }

  void stop() {
    if (!_active) return;
    _active = false;
    if (_realAttached) {
      VisualizerBridge.stopRealAudio();
      _realAttached = false;
    }
    _timer?.cancel();
    _timer = null;
    _playbackSub?.cancel();
    _playbackSub = null;
  }

  void _tick() {
    VisualizerBridge.addPcm(_generate());
  }

  // Broadband synthesized signal: three frequency sweeps that drift
  // across bass / mid / treble, low-amplitude white-ish noise to
  // populate every FFT bin, all gated by a 2 Hz beat envelope so the
  // visualizer has a recognisable pulse. Amplitude scales by
  // playback state — louder when something's playing, quiet (but
  // not silent) when paused so the screen never goes dead.
  final _rng = Random();
  // Reused across ticks: addPcm() serialises the buffer into the platform-
  // channel message synchronously (before its first await), so the bytes are
  // copied out before the next tick overwrites this — no per-tick 4 KB alloc on
  // the UI isolate (30×/s) and the GC churn that came with it.
  late final Float32List _scratch = Float32List(_samplesPerTick * 2);
  Float32List _generate() {
    final amp = _playing ? 0.65 : 0.18;
    final out = _scratch;
    const beatHz = 2.0;

    for (var i = 0; i < _samplesPerTick; i++) {
      final t = (_frame * _samplesPerTick + i) / _sampleRate;

      // Beat envelope — same shape as a low-frequency tremolo.
      final beat = 0.5 + 0.5 * sin(2 * pi * beatHz * t);

      // Three slow LFO-modulated sweeps spanning the spectrum:
      //   bass:   60–180 Hz, sweeping at 0.31 Hz
      //   mid:   440–1500 Hz, sweeping at 0.47 Hz
      //   treble: 2 kHz–8 kHz, sweeping at 0.71 Hz
      final bassF   =   60 +   60 * (0.5 + 0.5 * sin(2 * pi * 0.31 * t));
      final midF    =  440 +  530 * (0.5 + 0.5 * sin(2 * pi * 0.47 * t));
      final trebleF = 2000 + 3000 * (0.5 + 0.5 * sin(2 * pi * 0.71 * t));

      final bass   = sin(2 * pi * bassF   * t) * 0.55;
      final mid    = sin(2 * pi * midF    * t) * 0.30;
      final treble = sin(2 * pi * trebleF * t) * 0.18;

      // Light broadband noise so every FFT bin gets some energy —
      // otherwise the spectrum-bar shader looks too quantised.
      final noise = (_rng.nextDouble() * 2 - 1) * 0.08;

      final sample = ((bass + mid + treble + noise) * beat * amp)
          .clamp(-1.0, 1.0)
          .toDouble();

      // Slight stereo de-correlation on the highs so the waveform
      // row of iChannel0 doesn't look identical on L/R.
      final rJitter = (_rng.nextDouble() * 2 - 1) * 0.03;
      final r = (sample + rJitter).clamp(-1.0, 1.0).toDouble();

      out[2 * i] = sample;
      out[2 * i + 1] = r;
    }
    _frame++;
    return out;
  }
}
