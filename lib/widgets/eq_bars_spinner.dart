import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/velvet_theme.dart';

/// Animated equalizer bars — the app's wave-bar mark (sidebar logo, no-art
/// placeholder) brought to life as a loading indicator. Five rounded bars
/// breathe around the brand's resting heights with staggered phases, like a
/// live EQ, over a soft accent glow.
class EqBarsSpinner extends StatefulWidget {
  final double width;
  final double height;
  const EqBarsSpinner({super.key, this.width = 64, this.height = 40});

  @override
  State<EqBarsSpinner> createState() => _EqBarsSpinnerState();
}

class _EqBarsSpinnerState extends State<EqBarsSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(painter: _EqBarsPainter(_t)),
    );
  }
}

class _EqBarsPainter extends CustomPainter {
  _EqBarsPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // Resting shape = the brand wave-bar mark (album_grid's no-art placeholder),
  // so the loading state, the logo, and the placeholder all speak one visual
  // language.
  static const _base = [0.45, 0.9, 0.6, 0.8, 0.4];
  // Whole cycles per loop (seamless repeat) with spread phases: neighbours
  // never move in lockstep, so it reads as music rather than a metronome.
  static const _cycles = [3, 5, 4, 6, 2];
  static const _phase = [0.0, 0.23, 0.47, 0.71, 0.11];

  @override
  void paint(Canvas canvas, Size size) {
    final n = _base.length;
    final gap = size.width * 0.06;
    final w = (size.width - gap * (n - 1)) / n;
    final glow = Paint()
      ..color = VelvetColors.primaryGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final solid = Paint()..color = VelvetColors.primary;
    for (int i = 0; i < n; i++) {
      final wave = math.sin(2 * math.pi * (_cycles[i] * t.value + _phase[i]));
      final h = (_base[i] + 0.30 * wave).clamp(0.18, 1.0) * size.height;
      final left = i * (w + gap);
      final cy = size.height / 2;
      final r = RRect.fromLTRBR(
          left, cy - h / 2, left + w, cy + h / 2, Radius.circular(w / 8));
      canvas.drawRRect(r, glow);
      canvas.drawRRect(r, solid);
    }
  }

  @override
  bool shouldRepaint(_EqBarsPainter old) => false; // repaint: t drives it
}
