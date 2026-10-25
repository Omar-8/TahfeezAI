import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Tahfeez's own geometric motif, drawn (no artwork): the eight-pointed
/// star of two overlapping squares, on a lattice of stars joined by short
/// bars — the star-and-cross family of Islamic geometry, kept to thin,
/// faint lines so it stays decoration, never in the way of the text.
class TahfeezGeometricPattern extends StatelessWidget {
  const TahfeezGeometricPattern({
    super.key,
    required this.color,
    this.spacing = 44,
    this.strokeWidth = 0.8,
    this.child,
  });

  /// The lines' colour (its alpha sets how faint).
  final Color color;

  /// Distance between star centres.
  final double spacing;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LatticePainter(color, spacing, strokeWidth),
    child: child,
  );
}

/// One eight-pointed star (two overlapping squares), outlined or filled.
class TahfeezStar extends StatelessWidget {
  const TahfeezStar({
    super.key,
    required this.color,
    this.size = 24,
    this.filled = true,
  });

  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StarPainter(color, filled),
  );
}

/// The outline of an eight-pointed star of circumradius [r] about [c]: 16
/// points, the outer ones every 45°, the inner ones between them where
/// the two squares cross.
Path tahfeezStarPath(Offset c, double r, {double rotation = 0}) {
  final inner = r * math.cos(math.pi / 4) / math.cos(math.pi / 8);
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final radius = i.isEven ? r : inner;
    final a = rotation - math.pi / 2 + i * math.pi / 8;
    final p = c + Offset(math.cos(a), math.sin(a)) * radius;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = r / 8;
    final star = tahfeezStarPath(c, filled ? r : r * 0.92);
    if (filled) {
      // The motif's open centre, cut out of it.
      star
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.28));
    }
    canvas.drawPath(star, paint);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.filled != filled;
}

class _LatticePainter extends CustomPainter {
  _LatticePainter(this.color, this.spacing, this.strokeWidth);

  final Color color;
  final double spacing, strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    final d = spacing;
    final r = d * 0.36;
    final small = d * 0.16;
    final path = Path();
    final cols = (size.width / d).ceil() + 1;
    final rows = (size.height / d).ceil() + 1;
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        final c = Offset(x * d, y * d);
        // A star at each lattice point…
        path.addPath(tahfeezStarPath(c, r), Offset.zero);
        // …bars to its right and lower neighbours…
        path
          ..moveTo(c.dx + r, c.dy)
          ..lineTo(c.dx + d - r, c.dy)
          ..moveTo(c.dx, c.dy + r)
          ..lineTo(c.dx, c.dy + d - r);
        // …and a small turned star in each cell's centre.
        path.addPath(
          tahfeezStarPath(
            c + Offset(d / 2, d / 2),
            small,
            rotation: math.pi / 8,
          ),
          Offset.zero,
        );
      }
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}
