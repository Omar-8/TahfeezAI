import 'package:flutter/material.dart';

import '../../localization/generated/app_localizations.dart';
import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// A centered loading indicator, for a screen/section that has nothing to
/// show yet. Kept trivial on purpose — this is the single place a future
/// milestone would add a skeleton/shimmer treatment if Tahfeez adopts one,
/// without touching every screen that shows a loading state today.
class TahfeezLoadingView extends StatefulWidget {
  const TahfeezLoadingView({super.key, this.message});

  final String? message;

  @override
  State<TahfeezLoadingView> createState() => _TahfeezLoadingViewState();
}

/// Loading as content arriving, not a spinner: a few soft rounded bars,
/// gently pulsing.
class _TahfeezLoadingViewState extends State<TahfeezLoadingView>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TahfeezRadii.md),
        ),
      ),
    );
    return Center(
      child: Semantics(
        label: widget.message,
        liveRegion: widget.message != null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(TahfeezSpacing.lg),
            child: FadeTransition(
              opacity: Tween(begin: 0.45, end: 1.0).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.smPlus,
                children: [
                  bar(1, 56),
                  bar(0.85, 16),
                  bar(0.6, 16),
                  if (widget.message != null)
                    Text(
                      widget.message!,
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
