import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/foundation_demo_screen.dart';
import '../../app/shell/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/memorize/presentation/memorize_screen.dart';
import '../../features/quran/presentation/quran_index_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../theme/gallery/component_gallery_screen.dart';
import 'app_routes.dart';
import 'quran_location_routing.dart';
import 'tafsir_routing.dart';

export 'app_routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          // The shell needs the *active* branch's location (see
          // `fullBleedContentProvider` on why it may only honor a spread's
          // width request while the Quran branch is on screen).
          currentLocation: state.uri.path,
        ),
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
                builder: (context, state) => const QuranIndexScreen(),
                routes: [
                  ...quranLocationRoutes(),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.memorize,
                builder: (context, state) => const MemorizeScreen(),
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
      ...tafsirRoutes(),
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
