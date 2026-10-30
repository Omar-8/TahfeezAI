/// Route paths, centralized so features never hardcode string paths inline.
///
/// `home`/`quran`/`settings` are the three [AppShell]-equivalent branches
/// (see `docs/ARCHITECTURE.md`'s Milestone 4 section for the shell-based
/// navigation decision). `search` lives inside the Quran branch, opened
/// from the Quran index's app bar.
/// `debugFoundation`/`debugGallery` are the Milestone 1/3 dev-proof
/// screens, kept reachable at non-root debug paths now that Home owns
/// `/` — they are not linked from any user-facing navigation.
///
/// Kept in its own file (rather than alongside the `GoRouter` provider in
/// `app_router.dart`) so `quran_location_routing.dart` can depend on these
/// path constants without an import cycle with `app_router.dart` itself.
abstract final class AppRoutes {
  static const home = '/home';
  static const quran = '/quran';
  static const search = '/quran/search';
  static const bookmarks = '/quran/bookmarks';
  static const memorize = '/memorize';
  static const settings = '/settings';
  static const about = '/settings/about';
  static const debugFoundation = '/debug/foundation';
  static const debugGallery = '/debug/gallery';
}
