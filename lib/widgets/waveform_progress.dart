// Waveform-style progress bar.
//
// A horizontal bank of vertical bars whose heights are pseudo-random
// per-track (deterministic based on a seed string, so the same track
// always renders the same shape). The played portion is filled with
// the primary color; the unplayed portion uses the dim track color.
// Tap-to-seek hands the resulting fraction up via onSeek.
//
// Why pseudo-random per-track and not real waveform peaks: getting
// real peaks requires either a server endpoint that returns them or a
// client-side decode. Both are real follow-ups, but a deterministic
// stylized waveform already reads as "music UI" and clearly indicates
// playback position. When real peaks become available, swap _seedBars
// for the real list.

import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/velvet_theme.dart';

class WaveformProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? seed;
  final void Function(double fraction)? onSeek;
  final double height;
  final int barCount;

  const WaveformProgress({
    Key? key,
    required this.progress,
    this.seed,
    this.onSeek,
    this.height = 32,
    this.barCount = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final bars = _seedBars(seed ?? '', barCount);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onSeek == null
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localX = details.localPosition.dx;
              final fraction = (localX / box.size.width).clamp(0.0, 1.0);
              onSeek!(fraction);
            },
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WaveformPainter(
            heights: bars,
            progress: clamped,
            playedColor: VelvetColors.primary,
            unplayedColor: VelvetColors.border2,
          ),
        ),
      ),
    );
  }

  /// Deterministic pseudo-random bar heights in [0.18, 1.0]. Same seed
  /// returns the same shape so the bar is stable across rebuilds.
  static List<double> _seedBars(String seed, int n) {
    final hash = seed.isEmpty ? 1 : seed.codeUnits.fold(1, (a, b) => a * 31 + b);
    final rng = Random(hash);
    return List.generate(n, (_) => 0.18 + rng.nextDouble() * 0.82);
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final gap = 1.5;
    final barWidth = (size.width - gap * (n - 1)) / n;
    final progressX = size.width * progress;

    for (int i = 0; i < n; i++) {
      final h = heights[i] * size.height;
      final left = i * (barWidth + gap);
      final centerY = size.height / 2;
      final rect = RRect.fromLTRBR(
        left,
        centerY - h / 2,
        left + barWidth,
        centerY + h / 2,
        Radius.circular(barWidth / 2),
      );
      final isPlayed = (left + barWidth / 2) <= progressX;
      canvas.drawRRect(
        rect,
        Paint()..color = isPlayed ? playedColor : unplayedColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress ||
      old.heights != heights ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
