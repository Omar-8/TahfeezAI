import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_elevation.dart';
import '../tahfeez_icon_sizes.dart';

/// One destination in [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail].
///
/// [isPrimary] marks the single destination that should read as the app's
/// main entry point (Quran, for the root shell) — see those widgets' doc
/// comments for why this exists as its own token-driven treatment rather
/// than a copy of the reference app's center pill button.
class TahfeezPrimaryNavItem {
  const TahfeezPrimaryNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.isPrimary = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool isPrimary;
}

/// A bottom navigation bar where exactly one destination — [isPrimary] — is
/// rendered as a raised, filled circular action instead of a plain icon.
///
/// This is Tahfeez's own answer to `docs/reference/03_NAVIGATION_MAP.md`'s
/// observation that the reference app gives Quran access special visual
/// weight: rather than cloning that app's specific center-pill artwork
/// (which `CLAUDE.md`'s clean-room rules forbid anyway), the emphasis is
/// built entirely from existing tokens (`TahfeezElevation`, `TahfeezRadii`,
/// the active `ColorScheme`) so it reads as part of the same design system
/// as every other component, not a one-off.
class TahfeezPrimaryNavigationBar extends StatelessWidget {
  const TahfeezPrimaryNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<TahfeezPrimaryNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _PrimaryNavBarItem(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryNavBarItem extends StatelessWidget {
  const _PrimaryNavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TahfeezPrimaryNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    if (!item.isPrimary) {
      final color = selected ? scheme.primary : scheme.onSurfaceVariant;
      return InkWell(
        onTap: onTap,
        // `end`, not `center`: the primary item's icon sits in a much
        // taller filled circle than a plain `Icon`, so centering each
        // item's Column independently (the previous approach) pushed
        // *that* item's label further down than its plain-icon siblings
        // -- aligning every item's label to the same bottom edge instead
        // keeps all labels on one shared line regardless of icon height.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.xs,
          children: [
            Icon(icon, size: TahfeezIconSize.lg, color: color),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      );
    }

    // The primary destination floats slightly above the bar in a filled
    // circle, so it reads as the shell's main action without needing a
    // separate FloatingActionButton (which would add a second navigation
    // idiom on top of the bar).
    return InkWell(
      onTap: onTap,
      // `end`, not `center` -- see the plain-item branch above for why:
      // this keeps "Quran"'s label on the exact same line as "Home"/
      // "Search" despite its much taller filled-circle icon. The circle
      // still floats above the bar via `Transform.translate` (a pure
      // paint-time shift, so it doesn't disturb this shared baseline) --
      // kept small (not the circle's full raise-worthy amount) because
      // `Transform.translate` doesn't reclaim layout space: every pixel of
      // upward shift becomes extra empty gap between the visible circle and
      // the label below it, on top of the `spacing` below, so a larger
      // offset here visibly pushes "Quran"'s label further from its icon
      // than "Home"/"Search"'s label sits from theirs.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        spacing: TahfeezSpacing.xs,
        children: [
          Transform.translate(
            offset: const Offset(0, -4),
            child: Material(
              color: scheme.primary,
              elevation: TahfeezElevation.high,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
                child: Icon(
                  icon,
                  size: TahfeezIconSize.lg,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          Text(
            item.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The tablet/desktop counterpart of [TahfeezPrimaryNavigationBar]: a side
/// [NavigationRail]-shaped column where the primary destination still gets
/// the same filled-circle treatment, so the "Quran is prominent" identity
/// holds across every breakpoint rather than only on phone.
class TahfeezPrimaryNavigationRail extends StatelessWidget {
  const TahfeezPrimaryNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<TahfeezPrimaryNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: TahfeezSpacing.lg,
            children: [
              for (var i = 0; i < items.length; i++)
                _PrimaryNavRailItem(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryNavRailItem extends StatelessWidget {
  const _PrimaryNavRailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TahfeezPrimaryNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TahfeezSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.xs,
          children: [
            if (item.isPrimary)
              Material(
                color: scheme.primary,
                elevation: TahfeezElevation.medium,
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
                  child: Icon(
                    icon,
                    size: TahfeezIconSize.lg,
                    color: scheme.onPrimary,
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: TahfeezIconSize.lg,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: item.isPrimary ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
