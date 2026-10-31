// The curve through the band thumbs, and the painter that draws it under the
// sliders.
//
// The line is a monotone cubic (Fritsch–Carlson) through one point per band:
// it passes through every thumb and never overshoots one, so a single boosted
// band reads as a bump, not a wave. The painter also draws the faint 5 dB
// grid, the dragged band's column, the fill from the curve down to 0 dB, and
// a ring the colour of the card around every node, so the thumb the slider
// paints on top reads as a point on the line.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// Tangent per point for a monotone cubic through (xs, ys): the average of
/// the neighbouring secants where the data keeps direction, zero at a local
/// extremum or on a flat segment, and clipped so no segment overshoots.
List<double> monotoneSlopes(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return List<double>.filled(n, 0);
  final d = [
    for (var i = 0; i < n - 1; i++) (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]),
  ];
  final m = List<double>.filled(n, 0);
  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (var i = 1; i < n - 1; i++) {
    m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (d[i] == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / d[i];
    final b = m[i + 1] / d[i];
    final s = a * a + b * b;
    if (s > 9) {
      final t = 3 / math.sqrt(s);
      m[i] = t * a * d[i];
      m[i + 1] = t * b * d[i];
    }
  }
  return m;
}

/// The cubic Bézier path through [points] (ascending x) with
/// [monotoneSlopes] tangents; a lone point is a bare moveTo.
Path curvePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return path;
  final xs = [for (final p in points) p.dx];
  final ys = [for (final p in points) p.dy];
  final m = monotoneSlopes(xs, ys);
  for (var i = 0; i < points.length - 1; i++) {
    final h = xs[i + 1] - xs[i];
    path.cubicTo(
      xs[i] + h / 3,
      ys[i] + m[i] * h / 3,
      xs[i + 1] - h / 3,
      ys[i + 1] - m[i + 1] * h / 3,
      xs[i + 1],
      ys[i + 1],
    );
  }
  return path;
}

/// Paints the band curve across a panel whose columns are equal and in band
/// order: column i is centred at `width / n * (i + 0.5)`, and the rail runs
/// from [top] (max gain) down [length] px to min gain — the same numbers the
/// sliders are laid out from, which is what keeps the curve on the thumbs.
class EqCurvePainter extends CustomPainter {
  EqCurvePainter({
    required this.gains,
    required this.minDb,
    required this.maxDb,
    required this.top,
    required this.length,
    required this.accent,
    required this.ring,
    required this.grid,
    this.active,
  });

  final List<double> gains;
  final double minDb;
  final double maxDb;
  final double top;
  final double length;
  final Color accent;
  final Color ring;
  final Color grid;

  /// The band being dragged, if any: its column is tinted.
  final int? active;

  /// Screen y of [gain] on the rail, clamped to the rail's ends.
  double yFor(double gain) {
    final span = maxDb - minDb;
    final f = span <= 0 ? 0.5 : ((gain - minDb) / span).clamp(0.0, 1.0);
    return top + (1 - f) * length;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = gains.length;
    if (n == 0 || size.isEmpty) return;
    final colW = size.width / n;
    double xFor(int i) => colW * (i + 0.5);

    // A faint line every 5 dB; the 0 dB guide is the panel's own.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var g = 5.0; g < maxDb; g += 5) {
      canvas.drawLine(Offset(0, yFor(g)), Offset(size.width, yFor(g)), gridPaint);
    }
    for (var g = -5.0; g > minDb; g -= 5) {
      canvas.drawLine(Offset(0, yFor(g)), Offset(size.width, yFor(g)), gridPaint);
    }

    final a = active;
    if (a != null && a >= 0 && a < n) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(colW * a + 2, top - 16, colW * (a + 1) - 2,
              top + length + 16),
          const Radius.circular(6),
        ),
        Paint()..color = accent.withValues(alpha: 0.07),
      );
    }

    final pts = [for (var i = 0; i < n; i++) Offset(xFor(i), yFor(gains[i]))];
    final curve = curvePath(pts);
    final zeroY = yFor(0);
    final fill = Path.from(curve)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.drawPath(fill, Paint()..color = accent.withValues(alpha: 0.18));
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final ringPaint = Paint()..color = ring;
    for (final p in pts) {
      canvas.drawCircle(p, 11, ringPaint);
    }
  }

  @override
  bool shouldRepaint(EqCurvePainter old) =>
      !listEquals(old.gains, gains) ||
      old.active != active ||
      old.top != top ||
      old.length != length ||
      old.minDb != minDb ||
      old.maxDb != maxDb ||
      old.accent != accent ||
      old.ring != ring ||
      old.grid != grid;
}
