/// Route paths, centralized so features never hardcode string paths inline.
///
/// `home`/`quran`/`memorize` are the [AppShell]'s three tabs; `settings`
/// (with `about`) and `qibla` open over them from the side menu
/// (`app_menu.dart`), back returning to the tab (see `docs/ARCHITECTURE.md`'s
/// Milestone 4 section for the shell-based navigation decision). `search`
/// lives inside the Quran branch, opened
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
  static const qibla = '/qibla';
  static const athkar = '/athkar';

  /// An athkar section (its `AthkarGroup.name`): its chapters.
  static String athkarSection(String name) => '/athkar/section/$name';

  /// An athkar category ([AthkarCategory.id]).
  static String athkarCategory(int id) => '/athkar/$id';

  /// A chapter's athkar one after another, from its [at]th.
  static String athkarRead(int id, {int at = 0}) => '/athkar/$id/read?at=$at';

  /// Prayer times (from Home and the side menu).
  static const prayer = '/prayer';

  /// The Hijri calendar (from Home's date).
  static const hijriCalendar = '/calendar';
  static const habits = '/habits';
  static const habitsAdd = '/habits/add';
  static const habitsNew = '/habits/new';

  /// A ready-made habit, before it is added.
  static String habitTemplate(String id) => '/habits/template/$id';

  /// A habit ([Habit.id]): its log, its settings.
  static String habit(String id) => '/habits/$id';

  /// A wird habit counted.
  static String habitCount(String id) => '/habits/$id/count';

  static const debugFoundation = '/debug/foundation';
  static const debugGallery = '/debug/gallery';
}
