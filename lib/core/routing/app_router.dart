import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/foundation_demo_screen.dart';
import '../theme/gallery/component_gallery_screen.dart';

part 'app_router.g.dart';

/// Route paths, centralized so features never hardcode string paths inline.
///
/// `foundationDemo` and `componentGallery` are dev/proof scaffolding
/// (Milestones 1 and 3) — feature routes are added by the milestone that
/// owns each screen (Home & Navigation adds the app shell in Milestone 4,
/// and so on), per this milestone's "do not build major feature screens
/// yet" scope.
abstract final class AppRoutes {
  static const foundationDemo = '/';
  static const componentGallery = '/gallery';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.foundationDemo,
    routes: [
      GoRoute(
        path: AppRoutes.foundationDemo,
        builder: (context, state) => const FoundationDemoScreen(),
      ),
      GoRoute(
        path: AppRoutes.componentGallery,
        builder: (context, state) => const ComponentGalleryScreen(),
      ),
    ],
  );
}
