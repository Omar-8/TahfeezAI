import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tahfeez_motion.dart';

/// The compass card: a ring of degree ticks with N, E, S, W, the Kaaba on
/// the ring at the qibla's bearing, and a needle from the centre to it.
/// [heading] (degrees from true north the phone points) turns the whole
/// card, so north on the dial points north in the world — `null` when there
/// is no compass: the dial still, north up. [facing]: the needle and the
/// ring glow in the app's green.
class QiblaDial extends StatefulWidget {
  const QiblaDial({
    super.key,
    required this.bearing,
    required this.heading,
    required this.facing,
    required this.labels,
    this.enabled = true,
  });

  final double bearing;
  final double? heading;
  final bool facing;

  /// N, E, S, W in the app's language.
  final ({String north, String east, String south, String west}) labels;

  /// Off: a faint dial (no place yet).
  final bool enabled;

  @override
  State<QiblaDial> createState() => _QiblaDialState();
}

class _QiblaDialState extends State<QiblaDial> {
  /// The dial's turn, unwrapped (359° → 1° is +2°, not −358°), so it never
  /// spins the long way round.
  double _turn = 0;
  double? _lastHeading;

  @override
  void initState() {
    super.initState();
    _follow(widget.heading);
  }

  @override
  void didUpdateWidget(QiblaDial old) {
    super.didUpdateWidget(old);
    _follow(widget.heading);
  }

  void _follow(double? heading) {
    if (heading == null) return;
    final last = _lastHeading;
    if (last == null) {
      _turn = -heading;
    } else {
      var d = (heading - last) % 360;
      if (d > 180) d -= 360;
      if (d < -180) d += 360;
      _turn -= d;
    }
    _lastHeading = heading;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glow = widget.facing ? scheme.primary : Colors.transparent;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow behind the ring, breathing in when facing the qibla.
          AnimatedContainer(
            duration: still ? Duration.zero : TahfeezMotionDuration.slow,
            curve: TahfeezMotionCurves.standard,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: widget.facing ? 0.45 : 0),
                  blurRadius: widget.facing ? 36 : 0,
                  spreadRadius: widget.facing ? 4 : 0,
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.35,
            duration: still ? Duration.zero : TahfeezMotionDuration.medium,
            child: AnimatedRotation(
              turns: widget.heading == null ? 0 : _turn / 360,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: Size.infinite,
                painter: _DialPainter(
                  bearing: widget.bearing,
                  facing: widget.facing,
                  scheme: scheme,
                  labels: widget.labels,
                  textDirection: Directionality.of(context),
                  textStyle: Theme.of(context).textTheme.titleLarge!,
                  enabled: widget.enabled,
                ),
              ),
            ),
          ),
          // Where the phone points: a mark at the top, still.
          const Align(alignment: Alignment.topCenter, child: _PhoneMark()),
        ],
      ),
    );
  }
}

class _PhoneMark extends StatelessWidget {
  const _PhoneMark();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(18, 14),
    painter: _TrianglePainter(Theme.of(context).colorScheme.onSurface),
  );
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.bearing,
    required this.facing,
    required this.scheme,
    required this.labels,
    required this.textDirection,
    required this.textStyle,
    required this.enabled,
  });

  final double bearing;
  final bool facing, enabled;
  final ColorScheme scheme;
  final ({String north, String east, String south, String west}) labels;
  final TextDirection textDirection;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 16;
    final dark = scheme.brightness == Brightness.dark;

    // The face: frosted, a hairline catching the light (the cards' glass).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            scheme.surfaceContainerLowest.withValues(alpha: dark ? 0.22 : 0.62),
            scheme.surfaceContainerLow.withValues(alpha: dark ? 0.10 : 0.36),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Outlined (owner, 2026-11-20): a strong outer ring, a fine inner one.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = facing ? 4 : 3
        ..color = facing
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: dark ? 0.55 : 0.45),
    );
    canvas.drawCircle(
      c,
      r - 30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = scheme.onSurface.withValues(alpha: 0.18),
    );

    // Ticks: every 5°, longer every 30°, longest at the four points.
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 90 == 0, mid = deg % 30 == 0;
      final len = major ? 18.0 : (mid ? 13.0 : 7.0);
      tick
        ..strokeWidth = major ? 3.4 : (mid ? 2.4 : 1.4)
        ..color = (deg == 0 ? scheme.primary : scheme.onSurface).withValues(
          alpha: major ? 0.95 : (mid ? 0.75 : 0.45),
        );
      final a = _angle(deg.toDouble());
      final o = c + Offset(math.cos(a), math.sin(a)) * (r - 7);
      final i = c + Offset(math.cos(a), math.sin(a)) * (r - 7 - len);
      canvas.drawLine(i, o, tick);
    }

    // N, E, S, W inside the ticks; north in the app's green.
    final points = [
      (0.0, labels.north, scheme.primary),
      (90.0, labels.east, scheme.onSurface),
      (180.0, labels.south, scheme.onSurface),
      (270.0, labels.west, scheme.onSurface),
    ];
    for (final (deg, text, color) in points) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: textStyle.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
        textDirection: textDirection,
      )..layout();
      final a = _angle(deg);
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 48);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      // Each letter faces outward, as on a printed compass card.
      canvas.rotate(a + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    if (!enabled) return;

    // The needle: from the centre to the Kaaba on the ring.
    const kaaba = 40.0;
    final a = _angle(bearing);
    final dir = Offset(math.cos(a), math.sin(a));
    final k = c + dir * (r - 52);
    final tip = c + dir * (r - 52 - kaaba / 2);
    final needle = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = LinearGradient(
        colors: [
          scheme.primary.withValues(alpha: 0.2),
          facing ? scheme.primary : scheme.primary.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromPoints(c, tip));
    canvas.drawLine(c, tip, needle);
    canvas.drawCircle(c, 9, Paint()..color = scheme.primary);
    canvas.drawCircle(
      c,
      4,
      Paint()..color = scheme.surface.withValues(alpha: 0.95),
    );

    // The Kaaba: a dark cube with its gold band and door, upright on the
    // ring — large, the dial's mark to find (owner, 2026-11-20).
    canvas.save();
    canvas.translate(k.dx, k.dy);
    canvas.rotate(a + math.pi / 2);
    const h = kaaba / 2;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-h, -h, kaaba, kaaba),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF1E1F1D));
    const gold = Color(0xFFC9A75B);
    canvas.drawRect(
      const Rect.fromLTWH(-h, -h + 9, kaaba, 5),
      Paint()..color = gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(h - 15, h - 16, 8, 14),
        const Radius.circular(1.5),
      ),
      Paint()..color = gold.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = facing ? 3 : 1.5
        ..color = facing ? scheme.primary : Colors.white.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  /// [degrees] clockwise from north → the canvas's angle (0 = east).
  static double _angle(double degrees) => (degrees - 90) * math.pi / 180;

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.bearing != bearing ||
      old.facing != facing ||
      old.scheme != scheme ||
      old.labels != labels ||
      old.enabled != enabled;
}
