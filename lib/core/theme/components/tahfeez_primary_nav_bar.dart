import 'package:flutter/gestures.dart' show kTouchSlop;
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
    // Switches on the finger lifting over the item (it barely moved): the
    // tap recognizer alone dropped quick taps made just after a switch,
    // while the new tab was being built. The InkWell gives the ripple.
    return _LiftTap(
      onTap: onTap,
      child: InkWell(
        onTap: () {},
        // (Screen readers tap through _LiftTap's own semantics.)
        excludeFromSemantics: true,
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
          // Centred; scrolling when taller than the screen (a phone on its
          // side, large text).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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

    // Switches on the finger lifting over the item (it barely moved): the
    // tap recognizer alone dropped quick taps made just after a switch,
    // while the new tab was being built. The InkWell gives the ripple.
    return _LiftTap(
      onTap: onTap,
      child: InkWell(
        onTap: () {},
        // (Screen readers tap through _LiftTap's own semantics.)
        excludeFromSemantics: true,
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
              // As the bar's: one line, up to 1.3× the text size, scaled
              // down to the rail's width if still too wide.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.3),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calls [onTap] when a pointer that went down on [child] lifts within a
/// few pixels of where it went down — no gesture arena involved.
class _LiftTap extends StatefulWidget {
  const _LiftTap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_LiftTap> createState() => _LiftTapState();
}

class _LiftTapState extends State<_LiftTap> {
  Offset? _down;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: widget.onTap,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _down = e.position,
      onPointerCancel: (_) => _down = null,
      onPointerUp: (e) {
        final down = _down;
        _down = null;
        if (down != null && (e.position - down).distance < kTouchSlop) {
          widget.onTap();
        }
      },
      child: widget.child,
    ),
  );
}
