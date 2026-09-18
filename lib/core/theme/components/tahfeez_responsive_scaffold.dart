import 'package:flutter/material.dart';

import '../app_breakpoints.dart';
import '../tahfeez_content_widths.dart';

/// One primary navigation destination in a [TahfeezResponsiveScaffold].
class TahfeezNavDestination {
  const TahfeezNavDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// A scaffold whose primary navigation placement adapts to
/// [TahfeezBreakpoint], per `docs/DESIGN_DIRECTION.md`'s responsive
/// guidance: a bottom [NavigationBar] on [TahfeezBreakpoint.phone], a side
/// [NavigationRail] from [TahfeezBreakpoint.tablet] upward. Body content is
/// centered and capped at [TahfeezContentWidth.maxReading] by default so a
/// phone-shaped layout never stretches edge-to-edge on a wide screen — the
/// "do not stretch the phone layout across large screens" rule.
///
/// This is layout only — it takes plain destinations/callbacks, not a
/// `go_router` dependency, so it stays reusable wherever a later milestone
/// wires real navigation state into it (e.g. the Home & Navigation
/// milestone's app shell).
class TahfeezResponsiveScaffold extends StatelessWidget {
  const TahfeezResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.destinations = const [],
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.constrainBodyWidth = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<TahfeezNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final bool constrainBodyWidth;

  @override
  Widget build(BuildContext context) {
    final breakpoint = TahfeezBreakpoint.of(context);

    Widget content = body;
    if (constrainBodyWidth) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TahfeezContentWidth.maxReading,
          ),
          child: content,
        ),
      );
    }

    if (destinations.isEmpty || breakpoint.isPhone) {
      return Scaffold(
        appBar: appBar,
        body: content,
        bottomNavigationBar: destinations.isEmpty ? null : _bottomNavBar(),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          _navigationRail(),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: d.selectedIcon == null ? null : Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
    );
  }

  Widget _navigationRail() {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: d.selectedIcon == null ? null : Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
