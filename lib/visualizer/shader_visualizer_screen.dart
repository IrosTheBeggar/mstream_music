import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../native/audio_capture.dart';
import '../singletons/media.dart';
import '../theme/velvet_theme.dart';
import 'spectrum_source.dart';
import 'viz_renderer.dart';

/// Pure-Flutter audio visualizer for desktop — no native code. Cycles through
/// Shadertoy presets ported to Flutter's runtime fragment-shader dialect
/// (single-pass via [SinglePassRenderer], multi-pass via [MultiPassRenderer]).
/// A [Ticker] advances time and the [SpectrumSource] each frame; the
/// spectrum/waveform is uploaded as the `iChannel0` audio texture so the ported
/// shader bodies run unchanged.
class ShaderVisualizerScreen extends StatefulWidget {
  const ShaderVisualizerScreen({super.key});

  @override
  State<ShaderVisualizerScreen> createState() => _ShaderVisualizerScreenState();
}

class _Preset {
  final String name;
  final VizRenderer Function() build;
  const _Preset(this.name, this.build);
}

class _ShaderVisualizerScreenState extends State<ShaderVisualizerScreen>
    with SingleTickerProviderStateMixin {
  static final List<_Preset> _presets = [
    _Preset('Spectrum Bars',
        () => SinglePassRenderer('shaders/visualizer/01-spectrum-bars.frag')),
    _Preset('Audio Tunnel',
        () => SinglePassRenderer('shaders/visualizer/02-audio-tunnel.frag')),
    _Preset('Plasma Pulse',
        () => SinglePassRenderer('shaders/visualizer/03-plasma-pulse.frag')),
    _Preset('4D Beats',
        () => SinglePassRenderer('shaders/visualizer/06-4d-beats.frag')),
    _Preset('Neonwave Sunrise',
        () => SinglePassRenderer('shaders/visualizer/07-neonwave-sunrise.frag')),
    _Preset('Neonwave Sunset',
        () => SinglePassRenderer('shaders/visualizer/08-neonwave-sunset.frag')),
    // Multi-pass: a 1×1 self-feedback band buffer feeds the scene.
    _Preset(
        'Cyber Fuji',
        () => MultiPassRenderer([
              PassDef('buffera', 'shaders/visualizer/04-cyber-fuji-buffera.frag',
                  ['music', 'buffera'],
                  fixed1x1: true),
              PassDef('image', 'shaders/visualizer/04-cyber-fuji-image.frag',
                  ['music', 'buffera']),
            ])),
    // Multi-pass: buffera (scene) -> bufferb (full-size feedback) ; bufferc (1×1
    // music state) ; image composites bufferb + bufferc.
    _Preset(
        'Hex Marching',
        () => MultiPassRenderer([
              PassDef('buffera', 'shaders/visualizer/05-hex-buffera.frag', []),
              PassDef('bufferb', 'shaders/visualizer/05-hex-bufferb.frag',
                  ['buffera', 'bufferb']),
              PassDef('bufferc', 'shaders/visualizer/05-hex-bufferc.frag',
                  ['music', 'bufferc'],
                  fixed1x1: true),
              PassDef('image', 'shaders/visualizer/05-hex-image.frag',
                  ['bufferb', 'bufferc']),
            ])),
    // 09 mountainbytes is omitted: its raymarch passes samplers to functions
    // (forbidden in SkSL runtime effects) and use unbounded loops — see
    // DESKTOP_PORT_PLAN.md.
  ];

  final SpectrumSource _spectrum = SpectrumSource();
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  final List<VizRenderer> _renderers = [];
  int _index = 0;
  bool _ready = false;

  ui.Image? _audioImage;
  bool _decoding = false;
  double _time = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Capture real playback audio (WASAPI loopback) while the visualizer is
    // open; SpectrumSource prefers it and falls back to synth when unavailable.
    AudioCapture.instance.start();
    _load();
  }

  Future<void> _load() async {
    try {
      for (final p in _presets) {
        final r = p.build();
        await r.load();
        _renderers.add(r);
      }
      if (!mounted) return;
      setState(() => _ready = true);
      _ticker.start();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _setPreset(int i) => setState(() => _index = i);
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
  // is async, so we skip frames while one is in flight (a 512×2 image never backs
  // up in practice) and keep showing the previous one.
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
    AudioCapture.instance.stop();
    _ticker.dispose();
    for (final r in _renderers) {
      r.dispose();
    }
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
    if (!_ready) {
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
                renderer: () =>
                    _index < _renderers.length ? _renderers[_index] : null,
                image: () => _audioImage,
                time: () => _time,
                repaint: _repaint,
              ),
            ),
            _closeButton(),
            _controls(),
          ],
        ),
      ),
    );
  }

  // Explicit exit — mobile has no window chrome to close the screen with, and
  // the fullscreen tap gesture is taken by preset cycling. SafeArea keeps the
  // button clear of the notch.
  Widget _closeButton() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close),
              color: Colors.white70,
              tooltip: 'Close visualizer',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
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
        // SafeArea: keep the preset row above the iPhone home indicator.
        child: SafeArea(
          top: false,
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
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  final VizRenderer? Function() renderer;
  final ui.Image? Function() image;
  final double Function() time;

  _VizPainter({
    required this.renderer,
    required this.image,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final r = renderer();
    final img = image();
    if (r == null || img == null) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0xFF000000));
      return;
    }
    r.render(canvas, size, time(), img);
  }

  @override
  bool shouldRepaint(covariant _VizPainter old) => false;
}
