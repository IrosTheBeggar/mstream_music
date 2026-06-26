import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../native/projectm_desktop.dart';
import '../singletons/media.dart';
import '../theme/velvet_theme.dart';

/// Desktop Milkdrop visualizer: drives the native projectM render shim
/// (projectm_desktop.dll) each frame — feeds synthesized PCM, renders a frame
/// offscreen, reads it back, and shows it. Loads the bundled `.milk` presets.
///
/// projectM renders bottom-up (GL), so the painter flips vertically. CPU readback
/// at a modest fixed size keeps it backend-agnostic; tap or ‹ › cycles presets.
class ProjectMScreen extends StatefulWidget {
  const ProjectMScreen({super.key});

  @override
  State<ProjectMScreen> createState() => _ProjectMScreenState();
}

class _ProjectMScreenState extends State<ProjectMScreen>
    with SingleTickerProviderStateMixin {
  static const int _rw = 640, _rh = 360;

  final ProjectMDesktop _pm = ProjectMDesktop.instance;
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  ui.Image? _image;
  bool _decoding = false;
  bool _ready = false;
  String? _error;

  List<String> _presets = const [];
  int _presetIndex = 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (!_pm.init(_rw, _rh)) {
      setState(() => _error = 'projectM init failed: ${_pm.lastError()}');
      return;
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _presets = manifest
          .listAssets()
          .where((k) => k.startsWith('assets/presets/') && k.endsWith('.milk'))
          .toList()
        ..sort();
    } catch (_) {
      _presets = const [];
    }
    if (_presets.isNotEmpty) await _loadPreset(0, smooth: false);
    if (!mounted) return;
    setState(() => _ready = true);
    _ticker.start();
  }

  Future<void> _loadPreset(int i, {bool smooth = true}) async {
    if (_presets.isEmpty) return;
    _presetIndex = i % _presets.length;
    try {
      final milk = await rootBundle.loadString(_presets[_presetIndex]);
      _pm.loadPresetData(milk, smooth: smooth);
    } catch (_) {/* skip a bad preset */}
    if (mounted) setState(() {});
  }

  void _next() => _loadPreset(_presetIndex + 1);
  void _prev() => _loadPreset(_presetIndex - 1 + _presets.length);

  // Mono synth PCM (the Android default-source strategy) so presets react with
  // no mic/permissions. Amplitude follows real play/pause.
  final Random _rng = Random();
  double _pb = 0, _pm2 = 0, _pt = 0;
  int _frame = 0;
  final Float32List _pcm = Float32List(512);

  Float32List _synthPcm() {
    const sr = 44100.0;
    final amp =
        MediaManager().audioHandler.playbackState.value.playing ? 0.65 : 0.18;
    final tMid = (_frame * 512 + 256) / sr;
    final bassF = 60 + 60 * (0.5 + 0.5 * sin(2 * pi * 0.31 * tMid));
    final midF = 440 + 530 * (0.5 + 0.5 * sin(2 * pi * 0.47 * tMid));
    final trebleF = 2000 + 3000 * (0.5 + 0.5 * sin(2 * pi * 0.71 * tMid));
    final dB = 2 * pi * bassF / sr, dM = 2 * pi * midF / sr, dT = 2 * pi * trebleF / sr;
    for (var i = 0; i < 512; i++) {
      final t = (_frame * 512 + i) / sr;
      final beat = 0.5 + 0.5 * sin(2 * pi * 2.0 * t);
      _pb += dB;
      _pm2 += dM;
      _pt += dT;
      _pcm[i] = ((sin(_pb) * 0.55 +
                  sin(_pm2) * 0.30 +
                  sin(_pt) * 0.18 +
                  (_rng.nextDouble() * 2 - 1) * 0.08) *
              beat *
              amp)
          .clamp(-1.0, 1.0)
          .toDouble();
    }
    _pb %= 2 * pi;
    _pm2 %= 2 * pi;
    _pt %= 2 * pi;
    _frame++;
    return _pcm;
  }

  void _onTick(Duration elapsed) {
    _pm.addPcm(_synthPcm());
    // Skip a render while the previous frame is still decoding — the render
    // reuses one native buffer, so we must not overwrite it mid-decode.
    if (_decoding) return;
    final bytes = _pm.renderFrame();
    if (bytes == null) return;
    _decoding = true;
    ui.decodeImageFromPixels(bytes, _rw, _rh, ui.PixelFormat.rgba8888, (img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      _image?.dispose();
      _image = img;
      _decoding = false;
      _repaint.value++;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pm.dispose();
    _image?.dispose();
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
        child: Text(_error!,
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
      onTap: _next,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _PmPainter(() => _image, _repaint)),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final label = _presets.isEmpty
        ? 'No presets'
        : '${_presetName(_presets[_presetIndex])}   ${_presetIndex + 1}/${_presets.length}';
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
                onPressed: _prev),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.white70,
                tooltip: 'Next preset',
                onPressed: _next),
          ],
        ),
      ),
    );
  }

  static String _presetName(String assetKey) {
    var n = assetKey.split('/').last;
    if (n.endsWith('.milk')) n = n.substring(0, n.length - 5);
    return n;
  }
}

class _PmPainter extends CustomPainter {
  final ui.Image? Function() image;
  _PmPainter(this.image, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final img = image();
    if (img == null) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0xFF000000));
      return;
    }
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Offset.zero & size;
    canvas.save();
    // projectM renders bottom-up (GL row order) — flip vertically for display.
    canvas.translate(0, size.height);
    canvas.scale(1, -1);
    canvas.drawImageRect(
        img, src, dst, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PmPainter old) => false;
}
