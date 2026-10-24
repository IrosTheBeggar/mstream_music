import 'package:material_ui/material_ui.dart';

/// Keep a copy's own glyph while browsing a connected server: a folder with
/// a down arrow (the webapp's button icon), drawn on its 24-grid as a
/// 2-wide stroke with round caps and joins. Never `Icons.library_add` (⊞):
/// on the same bars that glyph means "add to the queue" (Add all, the
/// folder sheet's Add All), and two ⊞ verbs side by side are the worst
/// confusion a page could hold.
///
/// Decorative: whatever it sits in names the action.
class KeepFolderGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const KeepFolderGlyph({super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _KeepFolderPainter(color)),
        ),
      );
}

class _KeepFolderPainter extends CustomPainter {
  final Color color;
  _KeepFolderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // The icon's own 24-unit grid, scaled to the box.
    final s = size.shortestSide / 24;
    canvas.save();
    canvas.scale(s);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    const r = Radius.circular(2);
    // M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z
    final folder = Path()
      ..moveTo(3, 7)
      ..arcToPoint(const Offset(5, 5), radius: r)
      ..lineTo(9, 5)
      ..lineTo(11, 7)
      ..lineTo(19, 7)
      ..arcToPoint(const Offset(21, 9), radius: r)
      ..lineTo(21, 17)
      ..arcToPoint(const Offset(19, 19), radius: r)
      ..lineTo(5, 19)
      ..arcToPoint(const Offset(3, 17), radius: r)
      ..close();
    // M12 10v6 · M9.5 13.5L12 16l2.5-2.5
    final arrow = Path()
      ..moveTo(12, 10)
      ..lineTo(12, 16)
      ..moveTo(9.5, 13.5)
      ..lineTo(12, 16)
      ..lineTo(14.5, 13.5);
    canvas.drawPath(folder, stroke);
    canvas.drawPath(arrow, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeepFolderPainter old) => old.color != color;
}
