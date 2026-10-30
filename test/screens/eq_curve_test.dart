// The curve helper: monotone tangents (flat → 0, an extremum → 0, a run keeps
// its sign), a path that passes through every band point without
// overshooting, and a painter that maps gains onto the rail and repaints only
// when its inputs change.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/screens/eq/eq_curve.dart';

void main() {
  group('monotoneSlopes', () {
    test('a flat line has zero tangents everywhere', () {
      expect(monotoneSlopes([0, 1, 2, 3], [5, 5, 5, 5]), [0, 0, 0, 0]);
    });

    test('a peak gets a zero tangent; the runs either side keep their sign',
        () {
      final m = monotoneSlopes([0, 1, 2, 3, 4], [0, 2, 3, 1, 0]);
      expect(m[2], 0);
      expect(m[1], greaterThan(0));
      expect(m[3], lessThan(0));
    });

    test('fewer than two points: nothing to slope', () {
      expect(monotoneSlopes([1], [1]), [0]);
      expect(monotoneSlopes([], []), isEmpty);
    });
  });

  group('curvePath', () {
    List<Offset> sample(Path p) {
      final out = <Offset>[];
      for (final metric in p.computeMetrics()) {
        for (var d = 0.0; d <= metric.length; d += 0.5) {
          out.add(metric.getTangentForOffset(d)!.position);
        }
      }
      return out;
    }

    test('passes through every point and never overshoots', () {
      const rock = [5.0, 4.9, 3.9, 2.8, 0.7, -0.7, 1.3, 3.2, 4.2, 5.0];
      final pts = [
        for (var i = 0; i < rock.length; i++)
          Offset(16 + i * 32.0, 248 - rock[i] * 14.7),
      ];
      final s = sample(curvePath(pts));
      for (final p in pts) {
        expect(s.any((q) => (q - p).distance < 0.6), isTrue,
            reason: 'misses $p');
      }
      final ys = pts.map((p) => p.dy);
      final lo = ys.reduce(math.min);
      final hi = ys.reduce(math.max);
      for (final q in s) {
        expect(q.dy, inInclusiveRange(lo - 0.01, hi + 0.01));
      }
    });

    test('a lone point is a bare moveTo', () {
      expect(curvePath([const Offset(3, 4)]).computeMetrics(), isEmpty);
    });
  });

  group('EqCurvePainter', () {
    EqCurvePainter make({List<double> gains = const [0, 1, 2], int? active}) =>
        EqCurvePainter(
          gains: gains,
          minDb: -15,
          maxDb: 15,
          top: 44,
          length: 400,
          active: active,
          accent: const Color(0xFFFFAB00),
          ring: const Color(0xFF242424),
          grid: const Color(0xFF333333),
        );

    test('maps gains onto the rail: max at the top, min at the bottom', () {
      final p = make();
      expect(p.yFor(15), 44);
      expect(p.yFor(-15), 444);
      expect(p.yFor(0), 244);
      expect(p.yFor(40), 44, reason: 'clamped to the rail');
    });

    test('repaints when a gain or the dragged band changes, not otherwise',
        () {
      expect(make().shouldRepaint(make()), isFalse);
      expect(make(gains: const [0, 1, 2.5]).shouldRepaint(make()), isTrue);
      expect(make(active: 1).shouldRepaint(make()), isTrue);
    });

    test('paints one band, ten bands and no bands without throwing', () {
      final rec = PictureRecorder();
      final canvas = Canvas(rec);
      make(gains: const [3]).paint(canvas, const Size(40, 500));
      make(gains: List.filled(10, 2), active: 9)
          .paint(canvas, const Size(320, 500));
      make(gains: const []).paint(canvas, const Size(320, 500));
      rec.endRecording();
    });
  });
}
