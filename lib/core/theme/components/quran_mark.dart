import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tahfeez_motion.dart';

/// The Quran tab's mark (owner's choice, 2026-11-20, design A): an open
/// Mushaf with a pointed arch rising from its spine — after the app icon,
/// simplified to read at a glance; white on a green circle (in light mode
/// the green of Home's "AI"), a line of gold under the pages. Tahfeez's own
/// drawing. Round it, a green arc going round and round on a faint track,
/// and every two seconds a pulse (owner, 2026-11-20).
class QuranMark extends StatefulWidget {
  const QuranMark({super.key, required this.size, this.selected = false});

  /// The circle's diameter.
  final double size;

  /// The tab on screen: the circle a shade deeper, its track brighter.
  final bool selected;

  /// The pulse: a green glow swelling and fading, a green ring spreading
  /// out — still between; none with animations off.
  static const glowEvery = Duration(seconds: 2);
  static const glowFirst = Duration(seconds: 1);
  static const glowLength = Duration(milliseconds: 1400);

  /// One turn of the arc.
  static const spinRound = Duration(milliseconds: 2400);

  /// The arc going round without end (the app). Tests turn it off
  /// (`test/flutter_test_config.dart`) so screens with the tab bar settle.
  @visibleForTesting
  static bool spinning = true;

  /// How far out of the circle the arc's track is.
  static const trackGap = 4.0;

  /// The mark's green: Home's "AI" green in light mode (owner,
  /// 2026-11-20: the primary was too dark there), the primary in dark.
  static Color greenOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : TahfeezExplorationPalette.lightPrimaryAccent;
  }

  @override
  State<QuranMark> createState() => _QuranMarkState();
}

class _QuranMarkState extends State<QuranMark> with TickerProviderStateMixin {
  late final _glow = AnimationController(
    vsync: this,
    duration: QuranMark.glowLength,
  );
  late final _spin = AnimationController(
    vsync: this,
    duration: QuranMark.spinRound,
  );
  Timer? _next;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _next?.cancel();
      _next = null;
      _glow.value = 0;
      _spin.stop();
    } else {
      _next ??= Timer(QuranMark.glowFirst, _pulse);
      if (QuranMark.spinning && !_spin.isAnimating) unawaited(_spin.repeat());
    }
  }

  void _pulse() {
    if (!mounted || _still) return;
    // Not while another screen covers the tabs (its ticker muted).
    if (TickerMode.valuesOf(context).enabled) unawaited(_glow.forward(from: 0));
    _next = Timer(QuranMark.glowEvery, _pulse);
  }

  @override
  void dispose() {
    _next?.cancel();
    _glow.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = QuranMark.greenOf(context);
    final size = widget.size;
    final selected = widget.selected;
    final mark = AnimatedContainer(
      duration: _still ? Duration.zero : TahfeezMotionDuration.medium,
      curve: TahfeezMotionCurves.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? green : Color.lerp(green, scheme.surface, 0.18),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: selected ? 0.35 : 0.18),
            blurRadius: selected ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: const CustomPaint(painter: _QuranMarkPainter()),
      ),
    );
    // Its own layer: the arc going round repaints the mark alone.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_glow, _spin]),
        child: mark,
        builder: (context, child) {
          final t = _glow.value;
          // The glow swells and fades; the ring spreads and fades.
          final g = math.sin(math.pi * t);
          return CustomPaint(
            key: const ValueKey('quran-mark-pulse'),
            painter: QuranMarkRing(
              t: t,
              spin: _spin.value,
              spinning: _spin.isAnimating,
              selected: selected,
              colour: green,
              radius: size / 2,
            ),
            child: DecoratedBox(
              key: const ValueKey('quran-mark-glow'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (g > 0.01)
                    BoxShadow(
                      color: green.withValues(alpha: 0.55 * g),
                      blurRadius: 4 + 12 * g,
                      spreadRadius: 1 + 3 * g,
                    ),
                ],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Round the mark: its track, the arc going round it, and the pulse's ring
/// spreading from the circle's edge outwards, fading as it goes.
@visibleForTesting
class QuranMarkRing extends CustomPainter {
  QuranMarkRing({
    required this.t,
    required this.spin,
    required this.spinning,
    required this.selected,
    required this.colour,
    required this.radius,
  });

  /// The pulse, 0–1 (none at either end).
  final double t;

  /// Where the arc is on its round, 0–1; [spinning]: drawn.
  final double spin;
  final bool spinning;
  final bool selected;
  final Color colour;
  final double radius;

  /// How far out the pulse's ring spreads.
  static const reach = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final track = radius + QuranMark.trackGap;
    canvas.drawCircle(
      centre,
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colour.withValues(alpha: selected ? 0.25 : 0.14),
    );
    if (spinning) {
      // A quarter round, bright at its head, fading to its tail.
      const sweep = math.pi / 2;
      final head = spin * 2 * math.pi - math.pi / 2;
      final rect = Rect.fromCircle(center: centre, radius: track);
      canvas.drawArc(
        rect,
        head - sweep,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: sweep,
            colors: [colour.withValues(alpha: 0), colour],
            transform: GradientRotation(head - sweep),
          ).createShader(rect),
      );
    }
    if (t <= 0 || t >= 1) return;
    final out = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      centre,
      radius + 2 + reach * out,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - out) + 0.5
        ..color = colour.withValues(alpha: 0.7 * (1 - out)),
    );
  }

  @override
  bool shouldRepaint(QuranMarkRing old) =>
      old.t != t ||
      old.spin != spin ||
      old.spinning != spinning ||
      old.selected != selected ||
      old.colour != colour ||
      old.radius != radius;
}

class _QuranMarkPainter extends CustomPainter {
  const _QuranMarkPainter();

  static const _white = Color(0xFFFFFFFF);
  static const _gold = Color(0xFFE7D3A0);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 48 × 48 grid.
    final k = size.shortestSide / 48;
    canvas.save();
    canvas.translate((size.width - 48 * k) / 2, (size.height - 48 * k) / 2);
    canvas.scale(k);

    // The arch, hollow.
    final arch = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(24, 6)
      ..cubicTo(30, 12, 33, 16, 33, 21)
      ..cubicTo(33, 26, 28.5, 28, 24, 31)
      ..cubicTo(19.5, 28, 15, 26, 15, 21)
      ..cubicTo(15, 16, 18, 12, 24, 6)
      ..close()
      ..moveTo(24, 12.5)
      ..cubicTo(21, 16, 20, 18, 20, 20.5)
      ..cubicTo(20, 23, 22, 24.6, 24, 26)
      ..cubicTo(26, 24.6, 28, 23, 28, 20.5)
      ..cubicTo(28, 18, 27, 16, 24, 12.5)
      ..close();
    canvas.drawPath(arch, Paint()..color = _white);

    // The open pages.
    final pages = Path()
      ..moveTo(4, 30)
      ..cubicTo(11, 27, 18, 28, 24, 34)
      ..cubicTo(30, 28, 37, 27, 44, 30)
      ..lineTo(44, 35)
      ..cubicTo(37, 32.5, 30, 33.5, 24, 40)
      ..cubicTo(18, 33.5, 11, 32.5, 4, 35)
      ..close();
    canvas.drawPath(pages, Paint()..color = _white);

    // The gold under them.
    final under = Path()
      ..moveTo(7, 37.5)
      ..cubicTo(13, 36, 19, 37, 24, 42)
      ..cubicTo(29, 37, 35, 36, 41, 37.5);
    canvas.drawPath(
      under,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_QuranMarkPainter old) => false;
}
