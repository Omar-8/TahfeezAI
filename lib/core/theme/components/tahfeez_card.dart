import 'dart:ui' show ImageFilter;

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
    if (TahfeezGlass.of(context)) return _glass(context, shape, content);

    return Card(
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, customBorder: shape, child: content),
    );
  }

  /// Frosted glass ([TahfeezGlass]): what is behind it blurred, a sheen
  /// across it and a hairline edge catching the light.
  Widget _glass(BuildContext context, ShapeBorder? shape, Widget content) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(TahfeezRadii.lg);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLowest.withValues(
                  alpha: dark ? 0.22 : 0.62,
                ),
                scheme.surfaceContainerLow.withValues(
                  alpha: dark ? 0.12 : 0.38,
                ),
              ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: onTap == null
                ? content
                : InkWell(onTap: onTap, borderRadius: radius, child: content),
          ),
        ),
      ),
    );
  }
}

/// Makes the [TahfeezCard]s below it frosted glass (Home, over its sky).
class TahfeezGlass extends InheritedWidget {
  const TahfeezGlass({super.key, this.enabled = true, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TahfeezGlass>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(TahfeezGlass old) => old.enabled != enabled;
}
