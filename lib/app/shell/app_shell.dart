import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/components/components.dart';
import '../../core/theme/tahfeez_content_widths.dart';
import 'mini_player_region.dart';

/// Tahfeez's main app shell: the persistent chrome around Home/Quran/Search.
///
/// **Navigation architecture decision (Milestone 4)**: a shell-based
/// `go_router` model (`StatefulShellRoute.indexedStack`, wired in
/// `lib/core/routing/app_router.dart`) rather than the reference app's own
/// Activity-per-top-level-screen model
/// (`docs/reference/03_NAVIGATION_MAP.md` §1-2). This was chosen over a
/// pushed-route model for two reasons `docs/reference/03_NAVIGATION_MAP.md`
/// §7 itself flags as worth improving on: (1) each branch (Home/Quran/
/// Search) keeps its own independent navigation stack and scroll/state
/// restoration via `StatefulShellBranch`, which the reference app's Activity
/// boundaries only approximate; and (2) a single, shell-level
/// [MiniPlayerRegion] can persist across every branch, instead of being
/// re-created (and losing continuity) at every Activity boundary the way
/// the reference app's mini player is described as doing.
///
/// The primary navigation surface adapts by [TahfeezBreakpoint]: a bottom
/// [TahfeezPrimaryNavigationBar] on phone, a side
/// [TahfeezPrimaryNavigationRail] from tablet upward — both giving the
/// Quran destination a Tahfeez-owned "raised, filled circle" emphasis
/// (`core/theme/components/tahfeez_primary_nav_bar.dart`) rather than a
/// clone of the reference app's own center-pill artwork.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = TahfeezBreakpoint.of(context);
    final scheme = Theme.of(context).colorScheme;

    final items = [
      TahfeezPrimaryNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.navHome,
      ),
      TahfeezPrimaryNavItem(
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: l10n.navQuran,
        isPrimary: true,
      ),
      TahfeezPrimaryNavItem(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: l10n.navSearch,
      ),
    ];

    void onDestinationSelected(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final content = Column(
      children: [
        Expanded(child: _ConstrainedContent(child: navigationShell)),
        const _ConstrainedContent(child: MiniPlayerRegion()),
      ],
    );

    if (breakpoint.isPhone) {
      // Without this, the phone's own system navigation bar (the on-screen
      // gesture/button strip below everything this app draws) keeps
      // whatever color it had before Tahfeez started (usually plain black
      // or white) instead of matching `TahfeezPrimaryNavigationBar`'s own
      // `scheme.surfaceContainer` — a visible, jarring seam right where the
      // two bars meet, worse in dark mode where the mismatch is starkest.
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemNavigationBarStyle(scheme),
        child: Scaffold(
          body: content,
          bottomNavigationBar: TahfeezPrimaryNavigationBar(
            items: items,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: onDestinationSelected,
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemNavigationBarStyle(scheme),
      child: Scaffold(
        body: Row(
          children: [
            TahfeezPrimaryNavigationRail(
              items: items,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  /// Matches the phone's own system navigation bar to whatever color
  /// [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail] paint
  /// their own background with (`scheme.surfaceContainer`), and picks
  /// light-or-dark system icon glyphs by that color's actual brightness —
  /// never assumed from the app's overall theme mode, since a custom
  /// `ColorScheme.surfaceContainer` need not track light/dark 1:1.
  SystemUiOverlayStyle _systemNavigationBarStyle(ColorScheme scheme) {
    final isDarkBar =
        ThemeData.estimateBrightnessForColor(scheme.surfaceContainer) ==
        Brightness.dark;
    return SystemUiOverlayStyle(
      systemNavigationBarColor: scheme.surfaceContainer,
      systemNavigationBarIconBrightness: isDarkBar
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      // Android draws a translucent black scrim over the navigation bar by
      // default (API 29+, "contrast enforcement") regardless of the color
      // requested above — without disabling it, `surfaceContainer` still
      // renders visibly darker/duller than the real bar right above it,
      // which looks like the color was never applied at all.
      systemNavigationBarContrastEnforced: false,
    );
  }
}

/// Caps content at [TahfeezContentWidth.maxReading], matching
/// `TahfeezResponsiveScaffold`'s own "do not stretch the phone layout across
/// large screens" rule — reimplemented here (rather than reusing that
/// widget directly) because the shell's per-destination Quran emphasis
/// needs the bespoke [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail]
/// treatment that generic component doesn't offer.
class _ConstrainedContent extends StatelessWidget {
  const _ConstrainedContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TahfeezContentWidth.maxReading,
        ),
        child: child,
      ),
    );
  }
}
