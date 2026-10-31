import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../core/routing/quran_location_routing.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/components/components.dart';
import '../../core/theme/tahfeez_content_widths.dart';
import '../../features/recitation/presentation/recitation_controls.dart';

/// Tahfeez's main app shell: the persistent chrome around Home/Quran/Settings.
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
/// boundaries only approximate; and (2) shell-level chrome (the Mushaf's
/// recitation and listening bar) persists across every branch instead of
/// being re-created at every Activity boundary.
///
/// The primary navigation surface adapts by [TahfeezBreakpoint]: a bottom
/// [TahfeezPrimaryNavigationBar] on phone, a side
/// [TahfeezPrimaryNavigationRail] from tablet upward — both giving the
/// Quran destination a Tahfeez-owned "raised, filled circle" emphasis
/// (`core/theme/components/tahfeez_primary_nav_bar.dart`) rather than a
/// clone of the reference app's own center-pill artwork.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;

  /// The active branch's matched location (passed in by `appRouter`).
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = TahfeezBreakpoint.of(context);
    final scheme = Theme.of(context).colorScheme;
    // The tabs' own screens and the reader (a Quran location route, in
    // whichever tab opened it) lay themselves out across the width: their
    // sky edge to edge, their content in a reading column (SkyBackdrop, Ayah
    // mode), Home in two columns when wide (home_screen.dart), the printed
    // page as large as it fits. Every other screen keeps the shell's column.
    // Decided by the active branch's location alone, as StatefulShellRoute
    // keeps inactive branches mounted.
    final fullBleed = _isStandaloneMushafRoute(currentLocation) ||
        _fullWidthTabs.contains(Uri.tryParse(currentLocation)?.path) ||
        isQuranLocationPath(currentLocation);
    // While a Mushaf is open (or a recitation session runs), the live
    // recitation bar takes the place of the Home/Quran/Settings navigation.
    final recitationBar = ref.watch(recitationBarVisibleProvider);

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
      ),
      TahfeezPrimaryNavItem(
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        label: l10n.navMemorize,
      ),
      TahfeezPrimaryNavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.navSettings,
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
        Expanded(
          // The wrapper is kept in place (rather than swapped out) so the
          // branch `Navigator` subtree keeps its element identity — only the
          // constraint changes, which relayouts without rebuilding state.
          child: _ConstrainedContent(
            maxWidth: fullBleed
                ? double.infinity
                : TahfeezContentWidth.maxReading,
            child: navigationShell,
          ),
        ),
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
          // Screens drawn on beneath the glass navigation bar, which blurs
          // them — not the Mushaf under its recitation bar.
          extendBody: !recitationBar,
          body: content,
          bottomNavigationBar: RecitationBottomBar(
            navigation: TahfeezPrimaryNavigationBar(
              items: items,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemNavigationBarStyle(scheme),
      child: Scaffold(
        body: Row(
          children: [
            // Swapped in place (not removed) so `content` keeps its
            // position, and with it the branch Navigator's state.
            if (recitationBar)
              const SizedBox.shrink()
            else
              TahfeezPrimaryNavigationRail(
                items: items,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: onDestinationSelected,
              ),
            if (recitationBar)
              const SizedBox.shrink()
            else
              const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
        bottomNavigationBar: recitationBar
            ? const RecitationBottomBar(navigation: SizedBox.shrink())
            : null,
      ),
    );
  }

  /// The tabs' own screens, which keep their content in a column themselves.
  static const _fullWidthTabs = {
    AppRoutes.home,
    AppRoutes.quran,
    AppRoutes.memorize,
    AppRoutes.settings,
  };

  bool _isStandaloneMushafRoute(String location) {
    final segments = Uri.tryParse(location)?.pathSegments;
    return segments != null &&
        segments.length >= 3 &&
        quranLocationBranchRoots.contains(segments[0]) &&
        segments[1] == 'page';
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

/// Caps content at [maxWidth] (defaulting to
/// [TahfeezContentWidth.maxReading]), matching
/// `TahfeezResponsiveScaffold`'s own "do not stretch the phone layout across
/// large screens" rule — reimplemented here (rather than reusing that
/// widget directly) because the shell's per-destination Quran emphasis
/// needs the bespoke [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail]
/// treatment that generic component doesn't offer.
///
/// [maxWidth] is `double.infinity` for the tabs' own screens and the reader,
/// which then fill the available content area and keep their own columns.
class _ConstrainedContent extends StatelessWidget {
  const _ConstrainedContent({
    required this.child,
    this.maxWidth = TahfeezContentWidth.maxReading,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (maxWidth == double.infinity) {
      return SizedBox(width: double.infinity, child: child);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
