import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tahfeez_geometric_pattern.dart' show tahfeezStarPath;

/// A one-time burst of small eight-pointed stars and dots from [origin]
/// (a fraction of the box: the top centre, where the milestone card
/// slides in), rising, spreading, then drifting down and fading — a quiet
/// celebration over everything, never in the way (taps pass through).
/// [grand] (a khatmah complete) is fuller and longer. Under the phone's
/// "remove animations": nothing.
class TahfeezCelebration extends StatefulWidget {
  const TahfeezCelebration({
    super.key,
    this.grand = false,
    this.origin = const Alignment(0, -0.62),
    this.seed = 7,
  });

  final bool grand;
  final Alignment origin;
  final int seed;

  static const duration = Duration(milliseconds: 2600);
  static const grandDuration = Duration(milliseconds: 3800);

  @override
  State<TahfeezCelebration> createState() => _TahfeezCelebrationState();
}

class _TahfeezCelebrationState extends State<TahfeezCelebration>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.grand
        ? TahfeezCelebration.grandDuration
        : TahfeezCelebration.duration,
  );
  late final List<_Particle> _particles = _make();

  List<_Particle> _make() {
    final random = math.Random(widget.seed);
    final count = widget.grand ? 90 : 42;
    return [
      for (var i = 0; i < count; i++)
        _Particle(
          // Out and a little up: -165° … -15°.
          angle: -math.pi * (0.08 + 0.84 * random.nextDouble()),
          speed: 0.35 + random.nextDouble() * (widget.grand ? 0.6 : 0.4),
          size: 5 + random.nextDouble() * (widget.grand ? 11 : 8),
          spin: (random.nextDouble() - 0.5) * 7,
          star: random.nextDouble() < 0.6,
          tone: random.nextInt(3),
          delay: random.nextDouble() * (widget.grand ? 0.35 : 0.15),
          sway: random.nextDouble() * math.pi * 2,
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        !_controller.isAnimating &&
        _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final tones = [
      scheme.tertiary,
      scheme.primary,
      Color.lerp(scheme.tertiary, const Color(0xFFFFD27A), 0.55)!,
    ];
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            key: const ValueKey('celebration'),
            size: Size.infinite,
            painter: _BurstPainter(
              particles: _particles,
              t: _controller.value,
              seconds:
                  (widget.grand
                          ? TahfeezCelebration.grandDuration
                          : TahfeezCelebration.duration)
                      .inMilliseconds /
                  1000,
              origin: widget.origin,
              tones: tones,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.star,
    required this.tone,
    required this.delay,
    required this.sway,
  });

  /// Direction (radians) and speed (in the box's shorter sides a second).
  final double angle, speed;
  final double size, spin;
  final bool star;
  final int tone;

  /// When it sets off, as a share of the whole.
  final double delay;
  final double sway;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.particles,
    required this.t,
    required this.seconds,
    required this.origin,
    required this.tones,
  });

  final List<_Particle> particles;
  final double t, seconds;
  final Alignment origin;
  final List<Color> tones;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final unit = size.shortestSide;
    final start = origin.alongSize(size);
    // Gravity, in units a second².
    const g = 0.9;
    final paint = Paint();
    for (final p in particles) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0) continue;
      final s = local * seconds * (1 - p.delay);
      // Air slows it: the speed falls off, gravity takes over.
      final drag = (1 - math.exp(-1.8 * s)) / 1.8;
      final dx =
          math.cos(p.angle) * p.speed * drag +
          math.sin(s * 2.4 + p.sway) * 0.025;
      // Flatter upwards than sideways: it fans out over the screen.
      final dy =
          math.sin(p.angle) * p.speed * drag * 0.55 + 0.5 * g * s * s * 0.45;
      final position = start + Offset(dx, dy) * unit;
      // In quickly, out slowly over the last half.
      final opacity =
          (local < 0.08 ? local / 0.08 : 1.0) *
          (local > 0.5 ? (1 - local) / 0.5 : 1.0);
      if (opacity <= 0) continue;
      paint.color = tones[p.tone].withValues(alpha: opacity.clamp(0, 1) * 0.9);
      final r = p.size / 2;
      if (p.star) {
        canvas.drawPath(
          tahfeezStarPath(position, r, rotation: p.spin * s),
          paint,
        );
      } else {
        canvas.drawCircle(position, r * 0.45, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
