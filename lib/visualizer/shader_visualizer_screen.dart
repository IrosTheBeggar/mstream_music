import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../singletons/media.dart';
import '../theme/velvet_theme.dart';
import 'spectrum_source.dart';

/// Pure-Flutter audio visualizer for desktop — no native code, no platform
/// channels. Cycles through Shadertoy presets ported to Flutter's runtime
/// fragment-shader dialect (shaders/visualizer/*.frag). A [Ticker] advances time
/// and the [SpectrumSource] each frame; the spectrum/waveform is uploaded as the
/// `iChannel0` sampler so the ported shader bodies run unchanged.
///
/// Desktop counterpart to the Android native projectM/shader engine. Multi-pass
/// presets (04/05/09, which need ping-pong feedback buffers) aren't included —
/// they'd need an offscreen-render harness Flutter fragment shaders don't give
/// for free.
class ShaderVisualizerScreen extends StatefulWidget {
  const ShaderVisualizerScreen({super.key});

  @override
  State<ShaderVisualizerScreen> createState() => _ShaderVisualizerScreenState();
}

class _Preset {
  final String name;
  final String asset;
  const _Preset(this.name, this.asset);
}

class _ShaderVisualizerScreenState extends State<ShaderVisualizerScreen>
    with SingleTickerProviderStateMixin {
  static const List<_Preset> _presets = [
    _Preset('Spectrum Bars', 'shaders/visualizer/01-spectrum-bars.frag'),
    _Preset('Audio Tunnel', 'shaders/visualizer/02-audio-tunnel.frag'),
    _Preset('Plasma Pulse', 'shaders/visualizer/03-plasma-pulse.frag'),
    _Preset('Neonwave Sunrise', 'shaders/visualizer/07-neonwave-sunrise.frag'),
    _Preset('Neonwave Sunset', 'shaders/visualizer/08-neonwave-sunset.frag'),
  ];

  final SpectrumSource _spectrum = SpectrumSource();
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  final List<ui.FragmentProgram?> _programs =
      List<ui.FragmentProgram?>.filled(_presets.length, null);
  int _index = 0;
  ui.FragmentShader? _shader;

  ui.Image? _audioImage;
  bool _decoding = false;
  double _time = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      for (var i = 0; i < _presets.length; i++) {
        _programs[i] = await ui.FragmentProgram.fromAsset(_presets[i].asset);
      }
      if (!mounted) return;
      setState(() => _shader = _programs[0]?.fragmentShader());
      _ticker.start();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _setPreset(int i) {
    final prog = _programs[i];
    if (prog == null) return;
    _shader?.dispose();
    setState(() {
      _index = i;
      _shader = prog.fragmentShader();
    });
  }

  void _next() => _setPreset((_index + 1) % _presets.length);
  void _prev() => _setPreset((_index - 1 + _presets.length) % _presets.length);

  void _onTick(Duration elapsed) {
    _time = elapsed.inMicroseconds / 1e6;
    _spectrum.playing =
        MediaManager().audioHandler.playbackState.value.playing;
    _spectrum.advance();
    _refreshAudioImage();
    _repaint.value++;
  }

  // Build the iChannel0 image from the latest texture bytes. decodeImageFromPixels
  // is async, so we skip frames while one is in flight (a tiny 512×2 image never
  // backs up in practice) and keep showing the previous one.
  void _refreshAudioImage() {
    if (_decoding) return;
    _decoding = true;
    ui.decodeImageFromPixels(
      _spectrum.textureBytes,
      SpectrumSource.texWidth,
      SpectrumSource.texHeight,
      ui.PixelFormat.rgba8888,
      (img) {
        if (!mounted) {
          img.dispose();
          return;
        }
        _audioImage?.dispose();
        _audioImage = img;
        _decoding = false;
      },
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _audioImage?.dispose();
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
    if (_shader == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: _next, // tap anywhere to cycle, like a classic visualizer
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _VizPainter(
                shader: () => _shader,
                image: () => _audioImage,
                time: () => _time,
                repaint: _repaint,
              ),
            ),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              color: Colors.white70,
              tooltip: 'Previous preset',
              onPressed: _prev,
            ),
            Expanded(
              child: Text(
                '${_presets[_index].name}   ${_index + 1}/${_presets.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              color: Colors.white70,
              tooltip: 'Next preset',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  final ui.FragmentShader? Function() shader;
  final ui.Image? Function() image;
  final double Function() time;

  _VizPainter({
    required this.shader,
    required this.image,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final sh = shader();
    final img = image();
    if (sh == null || img == null) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0xFF000000));
      return;
    }
    // Uniform order MUST match the .frag preamble (iResolution xyz, iTime).
    sh.setFloat(0, size.width);
    sh.setFloat(1, size.height);
    sh.setFloat(2, 1.0);
    sh.setFloat(3, time());
    sh.setImageSampler(0, img);
    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(covariant _VizPainter old) => false;
}
