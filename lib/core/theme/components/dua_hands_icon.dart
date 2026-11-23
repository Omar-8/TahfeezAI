import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two open hands raised side by side, palms up, as in a dua — Tahfeez's
/// own outline (no icon set has one), drawn on Material's 24-unit grid to
/// sit beside the outlined icons. Its colour and size from [IconTheme], as
/// an [Icon]'s.
class DuaHandsIcon extends StatelessWidget {
  const DuaHandsIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: side,
      child: CustomPaint(
        painter: _HandsPainter(
          color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _HandsPainter extends CustomPainter {
  const _HandsPainter(this.color);

  final Color color;

  /// The hand on the right, palm towards us, on the 24 grid: a broad palm
  /// rounded beneath like a cup, four short fingers up (the little one by
  /// the middle), the thumb out to the side.
  static Path _hand() {
    Path capsule(Offset a, Offset b, double width) {
      final d = b - a;
      final angle = d.direction;
      return (Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, -width / 2, d.distance, width),
              Radius.circular(width / 2),
            ),
          ))
          .transform(
            (Matrix4.translationValues(a.dx, a.dy, 0)..rotateZ(angle)).storage,
          );
    }

    var hand = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          12.4,
          10.6,
          20.3,
          21.2,
          topLeft: const Radius.circular(0.7),
          topRight: const Radius.circular(0.7),
          bottomLeft: const Radius.circular(3.4),
          bottomRight: const Radius.circular(4.2),
        ),
      );
    // Little, ring, middle and index fingers.
    for (final (x, top) in [
      (13.2, 7.6),
      (15.3, 6.0),
      (17.4, 5.5),
      (19.5, 6.6),
    ]) {
      hand = Path.combine(
        PathOperation.union,
        hand,
        capsule(Offset(x, top + 0.8), Offset(x, 12.0), 1.6),
      );
    }
    // The thumb, out and up from the palm's side.
    hand = Path.combine(
      PathOperation.union,
      hand,
      capsule(const Offset(19.6, 18.0), const Offset(22.3, 13.4), 2.3),
    );
    return hand;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final hand = _hand();
    canvas.save();
    canvas.scale(s);
    // Cupped: the two leaning in, the little fingers together at the top,
    // the palms' heels apart beneath.
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
      }
      canvas.translate(16.3, 21.2);
      canvas.rotate(-6 * math.pi / 180);
      canvas.translate(-16.3 + 0.8, -21.2 + 0.2);
      canvas.drawPath(hand, fill);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandsPainter old) => old.color != color;
}
