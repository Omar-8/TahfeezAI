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

/// A Mushaf page still loading: the page's lines as soft bars, pulsing —
/// its shape before its text, instead of a spinner on an empty page.
class TahfeezPageSkeleton extends StatefulWidget {
  const TahfeezPageSkeleton({super.key, this.color, this.lines = 15});

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
            Widget line(int i) => TahfeezSkeletonBar(
              color: color,
              height: 14,
              // Most lines full, an ayah's end now and then.
              widthFactor: i == count - 1 && count > 1
                  ? 0.55
                  : i % 5 == 3
                  ? 0.8
                  : 1,
            );
            return ClipRect(
              child: Column(
                // Spread over the page's height; 18 apart when unbounded.
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: bounded ? 0 : 18,
                children: [for (var i = 0; i < count; i++) line(i)],
              ),
            );
          },
        ),
      ),
    );
  }
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
