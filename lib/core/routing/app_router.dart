import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/foundation_demo_screen.dart';
import '../../app/shell/app_shell.dart';
import '../../features/bookmarks/presentation/bookmarks_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/memorize/presentation/memorize_screen.dart';
import '../../features/quran/presentation/quran_index_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../theme/gallery/component_gallery_screen.dart';
import 'app_routes.dart';
import 'quran_location_routing.dart';

export 'app_routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute(
        // The tabs cross-fade (as indexedStack's, each kept alive, the
        // hidden ones' tickers off).
        navigatorContainerBuilder: (context, navigationShell, children) =>
            FadingBranches(
              index: navigationShell.currentIndex,
              children: children,
            ),
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          // The shell needs the *active* branch's location (see
          // `fullBleedContentProvider` on why it may only honor a spread's
          // width request while the Quran branch is on screen).
          // The topmost screen's, a pushed one (a Mushaf opened from Home)
          // included.
          currentLocation: GoRouter.of(context).state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                // What Home opens stays in Home's tab: back returns to it.
                routes: quranLocationRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.quran,
                builder: (context, state) => const QuranIndexScreen(),
                routes: [
                  ...quranLocationRoutes(),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'bookmarks',
                    builder: (context, state) => const BookmarksScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.memorize,
                builder: (context, state) => MemorizeScreen(
                  tab: state.uri.queryParameters['tab'] == 'progress'
                      ? MemorizeTab.progress
                      : MemorizeTab.plan,
                ),
                routes: [
                  ...quranLocationRoutes(),
                  // The progress, once its own page: its tab now.
                  GoRoute(
                    path: 'progress',
                    redirect: (context, state) =>
                        '${AppRoutes.memorize}?tab=progress',
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.debugFoundation,
        builder: (context, state) => const FoundationDemoScreen(),
      ),
      GoRoute(
        path: AppRoutes.debugGallery,
        builder: (context, state) => const ComponentGalleryScreen(),
      ),
    ],
  );
  // Any navigation (a tab, a screen opened or closed) puts the keyboard
  // away: a field left focused would otherwise bring it back each time its
  // screen is shown again (the Quran tab's search).
  void unfocus() => FocusManager.instance.primaryFocus?.unfocus();
  router.routerDelegate.addListener(unfocus);
  ref.onDispose(() {
    router.routerDelegate.removeListener(unfocus);
    // Released with its scope (the app keeps it for good; a test's scope
    // ends, and a router left registered with the binding would hold all
    // it reached).
    router.dispose();
  });
  return router;
}

/// The shell's tabs, each kept alive: the one shown fades in (160 ms), the
/// one before hidden at once. Only the shown one's tickers run
/// — a Mushaf in another tab knows it is out of sight.
class FadingBranches extends StatefulWidget {
  const FadingBranches({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadingBranches> createState() => _FadingBranchesState();
}

class _FadingBranchesState extends State<FadingBranches>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );
  late final _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);

  @override
  void didUpdateWidget(FadingBranches old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    // The phone's "remove animations": straight to the tab.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    // The one shown last (on top); each keyed, so moving it keeps it.
    final order = [
      for (var i = 0; i < widget.children.length; i++)
        if (i != index) i,
      index,
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final i in order)
          KeyedSubtree(
            key: ValueKey(i),
            // The tab left hidden at once: two screens drawn through each
            // other (their see-through skies) read as a glitch — the new one
            // simply fades in on the page.
            child: Offstage(
              offstage: i != index,
              child: TickerMode(
                enabled: i == index,
                // Always wrapped (the same tree shown or not, so nothing
                // is rebuilt), only the shown one's opacity moving.
                child: FadeTransition(
                  opacity: i == index ? _opacity : kAlwaysCompleteAnimation,
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
