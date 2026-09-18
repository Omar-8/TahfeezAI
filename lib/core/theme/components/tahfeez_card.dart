import 'package:flutter/material.dart';

import '../app_spacing.dart';

/// Tahfeez's default card: the app's own card treatment
/// (`docs/PROJECT_BRIEF.md`'s "its own card treatment" branding
/// requirement), built once so every screen gets the same padding/shape/
/// tonal-surface treatment instead of reinventing it.
///
/// Wraps [Card] (already themed by `buildTahfeezTheme`) and just adds the
/// standard content padding — most call sites only need `TahfeezCard(child:
/// ...)`. Pass [onTap] to make the whole card an ink-responsive button
/// clipped to the card's own shape.
class TahfeezCard extends StatelessWidget {
  const TahfeezCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TahfeezSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    final content = Padding(padding: padding, child: child);

    return Card(
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, customBorder: shape, child: content),
    );
  }
}
