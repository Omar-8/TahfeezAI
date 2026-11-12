import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/generated/app_localizations.dart';
import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';
import '../tahfeez_motion.dart';

/// A centered loading indicator, for a screen/section that has nothing to
/// show yet: a few soft rounded bars, gently pulsing ([TahfeezSkeleton]) —
/// content arriving, not a spinner.
class TahfeezLoadingView extends StatelessWidget {
  const TahfeezLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message,
        liveRegion: message != null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(TahfeezSpacing.lg),
            child: TahfeezSkeleton(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.smPlus,
                children: [
                  const TahfeezSkeletonBar(height: 56),
                  const TahfeezSkeletonBar(widthFactor: 0.85),
                  const TahfeezSkeletonBar(widthFactor: 0.6),
                  if (message != null)
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Mushaf page still loading, pulsing: its lines of words, justified from
/// the right, with an ayah's end marker here and there — the page's shape
/// before its text, instead of a spinner on an empty page.
class TahfeezPageSkeleton extends StatefulWidget {
  const TahfeezPageSkeleton({
    super.key,
    this.color,
    this.lines = 15,
    this.seed = 0,
  });

  /// Which arrangement of words and ayah ends (the page number, say): the
  /// same every time for one seed, different from page to page.
  final int seed;

  /// The bars' colour (the page's own text colour, faint); the theme's
  /// otherwise.
  final Color? color;

  /// How many lines the page has.
  final int lines;

  /// A page ready sooner shows no skeleton at all (no grey bars flashed
  /// for a few frames before it).
  static const delay = Duration(milliseconds: 250);

  @override
  State<TahfeezPageSkeleton> createState() => _TahfeezPageSkeletonState();
}

class _TahfeezPageSkeletonState extends State<TahfeezPageSkeleton> {
  bool _shown = false;
  late final Timer _later = Timer(TahfeezPageSkeleton.delay, () {
    if (mounted) setState(() => _shown = true);
  });

  @override
  void initState() {
    super.initState();
    _later;
  }

  @override
  void dispose() {
    _later.cancel();
    super.dispose();
  }

  Color? get color => widget.color;
  int get lines => widget.lines;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: TahfeezMotionDuration.medium,
      child: _bars(context),
    );
  }

  Widget _bars(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.lg,
        vertical: TahfeezSpacing.xl,
      ),
      child: TahfeezSkeleton(
        child: LayoutBuilder(
          builder: (context, box) {
            final bounded = box.hasBoundedHeight;
            // As many lines as fit, at least 28 apart: a short box (an
            // embedded page, a small window) gets fewer, never an overflow.
            final count = bounded
                ? (box.maxHeight ~/ 28).clamp(1, lines)
                : lines;
            final base = color ?? Theme.of(context).colorScheme.onSurface;
            return CustomPaint(
              size: Size(
                box.hasBoundedWidth ? box.maxWidth : 0,
                bounded ? box.maxHeight : count * 32.0,
              ),
              painter: TahfeezMushafSkeletonPainter(
                lines: count,
                seed: widget.seed,
                color: base.withValues(alpha: color == null ? 0.08 : 0.12),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints [lines] Mushaf lines filling the size: rounded words of varied
/// length, justified right to left (the Mushaf's lines run edge to edge),
/// and now and then an ayah's end — a ring with a dot for its number.
@visibleForTesting
class TahfeezMushafSkeletonPainter extends CustomPainter {
  const TahfeezMushafSkeletonPainter({
    required this.lines,
    required this.color,
    this.seed = 0,
  });

  final int lines;
  final Color color;
  final int seed;

  /// The space between words, in word thicknesses.
  static const gapFactor = 0.55;

  /// The words and ayah ends of each line, as (width, isAyahEnd), with the
  /// line's word thickness [t] and width [w]; deterministic for [seed].
  @visibleForTesting
  List<List<(double, bool)>> layout(double w, double t) {
    var state = (seed * 7919 + 104729) & 0x7fffffff;
    double next() {
      // xorshift32: the same "random" page for the same seed.
      state ^= (state << 13) & 0xffffffff;
      state ^= state >> 17;
      state ^= (state << 5) & 0xffffffff;
      return (state & 0xffff) / 0x10000;
    }

    final gap = t * gapFactor;
    final marker = t * 1.6;
    var sinceEnd = 0;
    return [
      for (var line = 0; line < lines; line++)
        () {
          final items = <(double, bool)>[];
          var used = 0.0;
          while (true) {
            // An ayah ends after a few words, more likely the longer since
            // the last one; never as a line's first item.
            final end =
                items.isNotEmpty &&
                !items.last.$2 &&
                sinceEnd > 6 &&
                next() < 0.02 + sinceEnd * 0.005;
            final width = end ? marker : t * (1.1 + next() * 3.4);
            final add = width + (items.isEmpty ? 0 : gap);
            if (used + add > w && items.length >= 2) break;
            if (used + add > w) {
              // A box too narrow for two words: one, shortened to fit.
              items.add((w - used - (items.isEmpty ? 0 : gap), false));
              break;
            }
            items.add((width, end));
            used += add;
            sinceEnd = end ? 0 : sinceEnd + 1;
          }
          return items;
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (lines <= 0 || size.width <= 0 || size.height <= 0) return;
    final pitch = size.height / lines;
    final t = (pitch * 0.42).clamp(8.0, 15.0);
    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = t * 0.2;
    final rows = layout(size.width, t);
    for (var i = 0; i < rows.length; i++) {
      final items = rows[i];
      final cy = pitch * (i + 0.5);
      final gap = t * gapFactor;
      final words = items
          .where((item) => !item.$2)
          .fold(0.0, (sum, item) => sum + item.$1);
      final markers = items
          .where((item) => item.$2)
          .fold(0.0, (sum, item) => sum + item.$1);
      // Justified as the Mushaf is: the words drawn out (kashida) to fill
      // the line, the gaps between them kept.
      final room = size.width - markers - gap * (items.length - 1);
      final stretch = words > 0 ? room / words : 1.0;
      var x = size.width; // From the right, as the Mushaf is read.
      for (final (natural, end) in items) {
        final width = end ? natural : natural * stretch;
        if (end) {
          final c = Offset(x - width / 2, cy);
          canvas
            ..drawCircle(c, width / 2 - ring.strokeWidth / 2, ring)
            ..drawCircle(c, width * 0.14, fill);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(x - width, cy - t / 2, x, cy + t / 2),
              Radius.circular(t / 2),
            ),
            fill,
          );
        }
        x -= width + gap;
      }
    }
  }

  @override
  bool shouldRepaint(TahfeezMushafSkeletonPainter old) =>
      old.lines != lines || old.color != color || old.seed != seed;
}

/// One soft rounded bar of a skeleton, [widthFactor] of the width, from
/// the reading start.
class TahfeezSkeletonBar extends StatelessWidget {
  const TahfeezSkeletonBar({
    super.key,
    this.widthFactor = 1,
    this.height = 16,
    this.color,
  });

  final double widthFactor;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.onSurface;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: color == null ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(TahfeezRadii.md),
        ),
      ),
    );
  }
}

/// Pulses [child] gently (still under the phone's "remove animations").
class TahfeezSkeleton extends StatefulWidget {
  const TahfeezSkeleton({super.key, required this.child});

  final Widget child;

  @override
  State<TahfeezSkeleton> createState() => _TahfeezSkeletonState();
}

class _TahfeezSkeletonState extends State<TahfeezSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The phone's "remove animations": still, not pulsing.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// A centered "nothing here yet" state — e.g. an empty bookmarks list or
/// empty read history (`docs/reference/11_HOME_SPEC.md` §4,
/// `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §2).
class TahfeezEmptyView extends StatelessWidget {
  const TahfeezEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CenteredOrScrolling(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              icon,
              size: TahfeezIconSize.xl * 1.5,
              color: scheme.onSurfaceVariant,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A centered error state with a retry affordance — for a failed load
/// (network manifest fetch, a corrupted resource) where the user has
/// something concrete to do next.
class TahfeezErrorView extends StatelessWidget {
  const TahfeezErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CenteredOrScrolling(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              Icons.error_outline,
              size: TahfeezIconSize.xl * 1.5,
              color: scheme.error,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null)
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centred in the space given; scrollable when that space is too short for
/// it (a small phone with large text). In an unbounded height (inside a
/// list), just the child.
class _CenteredOrScrolling extends StatelessWidget {
  const _CenteredOrScrolling({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (!box.hasBoundedHeight) return Center(child: child);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight,
            minWidth: box.hasBoundedWidth ? box.maxWidth : 0,
          ),
          child: Center(child: child),
        ),
      );
    },
  );
}
