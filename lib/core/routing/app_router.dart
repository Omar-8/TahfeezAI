import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/foundation_demo_screen.dart';
import '../../app/shell/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/quran_placeholder_screen.dart';
import '../../features/search/presentation/search_placeholder_screen.dart';
import '../theme/gallery/component_gallery_screen.dart';

part 'app_router.g.dart';

/// Route paths, centralized so features never hardcode string paths inline.
///
/// `home`/`quran`/`search` are the three [AppShell] branches this milestone
/// establishes (see `docs/ARCHITECTURE.md`'s Milestone 4 section for the
/// shell-based navigation decision). `debugFoundation`/`debugGallery` are
/// the Milestone 1/3 dev-proof screens, kept reachable at non-root debug
/// paths now that Home owns `/` — they are not linked from any user-facing
/// navigation.
abstract final class AppRoutes {
  static const home = '/home';
  static const quran = '/quran';
  static const search = '/search';
  static const debugFoundation = '/debug/foundation';
  static const debugGallery = '/debug/gallery';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.quran,
                builder: (context, state) => const QuranPlaceholderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchPlaceholderScreen(),
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
}
