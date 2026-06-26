import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../singletons/media.dart';
import '../theme/velvet_theme.dart';
import 'spectrum_source.dart';

/// Pure-Flutter audio-spectrum visualizer for desktop — no native code, no
/// platform channels. A [Ticker] advances time and the [SpectrumSource] each
/// frame; a [ui.FragmentShader] (shaders/visualizer_spectrum.frag) paints the
/// bars. Works anywhere Flutter runs.
///
/// This is the desktop counterpart to the Android native projectM/shader engine
/// (which stays gated to Android). First slice: one shader + the synthesized
/// audio source; more presets / real-audio capture can layer on top.
class ShaderVisualizerScreen extends StatefulWidget {
  const ShaderVisualizerScreen({super.key});

  @override
  State<ShaderVisualizerScreen> createState() => _ShaderVisualizerScreenState();
}

class _ShaderVisualizerScreenState extends State<ShaderVisualizerScreen>
    with SingleTickerProviderStateMixin {
  static const int _bandCount = 64;

  final SpectrumSource _spectrum = SpectrumSource(bandCount: _bandCount);
  late final Ticker _ticker = createTicker(_onTick);
  // Drives the painter's repaint without rebuilding the widget each frame.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  ui.FragmentShader? _shader;
  String? _error;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
          'shaders/visualizer_spectrum.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _ticker.start();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onTick(Duration elapsed) {
    _time = elapsed.inMicroseconds / 1e6;
    // Amplitude follows real playback: full when playing, quiet (not dead) when
    // paused — same feel as the Android source.
    _spectrum.playing =
        MediaManager().audioHandler.playbackState.value.playing;
    _spectrum.advance();
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text('Visualizer unavailable\n$_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: VelvetColors.textSecondary)),
      );
    }
    final shader = _shader;
    if (shader == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: CustomPaint(
        size: Size.infinite,
        painter: _VizPainter(
          shader: shader,
          time: () => _time,
          bands: _spectrum.bands,
          accent: VelvetColors.primary,
          repaint: _repaint,
        ),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double Function() time;
  final List<double> bands;
  final Color accent;

  _VizPainter({
    required this.shader,
    required this.time,
    required this.bands,
    required this.accent,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform order MUST match visualizer_spectrum.frag (set by flat float index).
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time());
    shader.setFloat(3, accent.r);
    shader.setFloat(4, accent.g);
    shader.setFloat(5, accent.b);
    for (var i = 0; i < bands.length; i++) {
      shader.setFloat(6 + i, bands[i]);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  // The repaint Listenable drives every frame; the painter instance itself never
  // changes meaningfully (it reads live time/bands by reference).
  @override
  bool shouldRepaint(covariant _VizPainter old) => false;
}
