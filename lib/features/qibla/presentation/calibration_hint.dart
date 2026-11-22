import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/tahfeez_card.dart';

/// How to sharpen the compass: a phone tracing a figure 8 (∞) — the
/// movement that recalibrates a phone's magnetometer — beside [text]. Round
/// and round without a stop for as long as it is on screen (owner,
/// 2026-11-20); still, on the path, with animations off.
class CalibrationHint extends StatefulWidget {
  const CalibrationHint({super.key, required this.text});

  final String text;

  /// One round of the 8.
  static const round = Duration(milliseconds: 3600);

  /// Round and round without end (the app). Tests turn it off
  /// (`test/flutter_test_config.dart`) so screens with it can settle: then
  /// a round, a breath ([rest]) and another, the screen still between.
  @visibleForTesting
  static bool endless = true;

  /// At rest between rounds (not [endless]).
  static const rest = Duration(milliseconds: 500);

  @override
  State<CalibrationHint> createState() => _CalibrationHintState();
}

class _CalibrationHintState extends State<CalibrationHint>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: CalibrationHint.round,
  );
  Timer? _next;
  bool _still = false;
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _next?.cancel();
      _next = null;
      _loop.stop();
      _loop.value = 0.125;
    } else if (_next == null && !_loop.isAnimating) {
      if (CalibrationHint.endless) {
        unawaited(_loop.repeat());
      } else {
        _round();
      }
    }
  }

  /// Once round, then (after a breath) again.
  void _round() {
    if (!mounted || _still) return;
    _loop.forward(from: 0).whenCompleteOrCancel(() {
      // (Also called as it is disposed.)
      if (_gone || _still) return;
      _next = Timer(CalibrationHint.rest, _round);
    });
  }

  @override
  void dispose() {
    _gone = true;
    _next?.cancel();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TahfeezGlassSurface(
      key: const ValueKey('qibla-calibration'),
      blur: false,
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Row(
          spacing: TahfeezSpacing.md,
          children: [
            SizedBox(
              width: 120,
              height: 72,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => CustomPaint(
                  painter: _FigureEightPainter(
                    t: _loop.value,
                    path: scheme.primary,
                    phone: scheme.onSurface,
                    screen: scheme.primaryContainer,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter({
    required this.t,
    required this.path,
    required this.phone,
    required this.screen,
  });

  /// Where on the loop, 0–1.
  final double t;
  final Color path, phone, screen;

  /// The lemniscate of Bernoulli (∞) at [a]: centred, width 2·[ax].
  static Offset _point(double a, double ax, double ay) {
    final s = math.sin(a), c = math.cos(a);
    final d = 1 + s * s;
    return Offset(ax * c / d, ay * 2 * s * c / d);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final ax = size.width / 2 - 10, ay = size.height / 2 - 8;

    // The path, dashed and faint.
    final dots = Paint()..color = path.withValues(alpha: 0.35);
    for (var i = 0; i < 48; i++) {
      final p = centre + _point(i / 48 * 2 * math.pi, ax, ay);
      canvas.drawCircle(p, 1.4, dots);
    }

    // Where it has just been: a trail fading behind it.
    final a = t * 2 * math.pi;
    if (t > 0 && t < 1) {
      const steps = 18;
      for (var i = steps; i > 0; i--) {
        final back = a - i * 0.06;
        if (back < 0) continue;
        canvas.drawCircle(
          centre + _point(back, ax, ay),
          2.2,
          Paint()..color = path.withValues(alpha: 0.7 * (1 - i / steps)),
        );
      }
    }

    // The phone on it, leaning into the curve (up or down the way it
    // goes; never flipped round at the ends).
    final p = centre + _point(a, ax, ay);
    final ahead = centre + _point(a + 0.05, ax, ay);
    final dx = ahead.dx - p.dx, dy = ahead.dy - p.dy;
    final lean = math.atan2(dy, dx.abs()) * (dx < 0 ? -1 : 1);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(lean * 0.6);
    const w = 16.0, h = 28.0;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-w / 2, -h / 2, w, h),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(body, Paint()..color = phone.withValues(alpha: 0.85));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-w / 2 + 2, -h / 2 + 3, w - 4, h - 6),
        const Radius.circular(1.5),
      ),
      Paint()..color = screen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) =>
      old.t != t ||
      old.path != path ||
      old.phone != phone ||
      old.screen != screen;
}
