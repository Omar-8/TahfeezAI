import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// One destination in [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail].
class TahfeezPrimaryNavItem {
  const TahfeezPrimaryNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// The app shell's bottom navigation bar: equal destinations, each an icon
/// over its label, the selected one in the primary colour.
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

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      // The bar keeps its height at any text size: labels grow up to 1.3×,
      // stay on one line, and the item scales down if that still doesn't
      // fit (very large text, long Arabic labels).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.xs,
          children: [
            Icon(icon, size: TahfeezIconSize.lg, color: color),
            Text(
              item.label,
              maxLines: 1,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tablet/desktop counterpart of [TahfeezPrimaryNavigationBar]: a side
/// [NavigationRail]-shaped column of the same destinations.
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
            Icon(
              icon,
              size: TahfeezIconSize.lg,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
