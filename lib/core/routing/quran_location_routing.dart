import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/mushaf/presentation/mushaf_reader_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../quran/domain/models/quran_location.dart';
import 'app_routes.dart';

/// `go_router` routes for every [QuranLocation] variant, nested under the
/// Quran branch (`AppRoutes.quran`). Deliberately six separate path
/// templates (one per variant) rather than one generic catch-all segment:
/// `go_router` path parameters (`:name`) match exactly one path segment
/// each, so a single embedded-slash-bearing parameter couldn't represent
/// `lib/quran/domain/quran_location_path.dart`'s encoding — a location's
/// *kind* is part of the route shape, its numeric fields are the path
/// parameters.
///
/// Five of the six variants open the real [ReaderScreen] (Milestone 6).
/// [QuranLocationPage] opens the real [MushafReaderScreen] (Milestone 7).
///
/// This file, like `app_router.dart` itself, is `core/routing`'s one
/// documented exception to `docs/ARCHITECTURE.md` §1's "core never depends
/// on a feature" rule: something has to wire route paths to screens, and
/// that composition-root role is `core/routing`'s alone — no other file
/// under `core/` may depend downward into `features/` or `quran/domain`.
int _parsePathInt(Map<String, String> params, String key) =>
    int.parse(params[key]!);

List<RouteBase> quranLocationRoutes() {
  return [
    GoRoute(
      path: 'surah/:surahNo',
      builder: (context, state) => ReaderScreen(
        // Per location: go_router keys a page by its route pattern, so going
        // from one surah to another would otherwise keep the first reader.
        key: ValueKey(state.matchedLocation),
        location: QuranLocation.surah(
          _parsePathInt(state.pathParameters, 'surahNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'ayah/:chapterNo/:verseNo',
      builder: (context, state) => ReaderScreen(
        // Per location: go_router keys a page by its route pattern, so going
        // from one surah to another would otherwise keep the first reader.
        key: ValueKey(state.matchedLocation),
        location: QuranLocation.ayah(
          _parsePathInt(state.pathParameters, 'chapterNo'),
          _parsePathInt(state.pathParameters, 'verseNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'ayah-range/:chapterNo/:fromVerseNo/:toVerseNo',
      builder: (context, state) => ReaderScreen(
        // Per location: go_router keys a page by its route pattern, so going
        // from one surah to another would otherwise keep the first reader.
        key: ValueKey(state.matchedLocation),
        location: QuranLocation.ayahRange(
          _parsePathInt(state.pathParameters, 'chapterNo'),
          _parsePathInt(state.pathParameters, 'fromVerseNo'),
          _parsePathInt(state.pathParameters, 'toVerseNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'juz/:juzNo',
      builder: (context, state) => ReaderScreen(
        // Per location: go_router keys a page by its route pattern, so going
        // from one surah to another would otherwise keep the first reader.
        key: ValueKey(state.matchedLocation),
        location: QuranLocation.juz(
          _parsePathInt(state.pathParameters, 'juzNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'hizb/:hizbNo',
      builder: (context, state) => ReaderScreen(
        // Per location: go_router keys a page by its route pattern, so going
        // from one surah to another would otherwise keep the first reader.
        key: ValueKey(state.matchedLocation),
        location: QuranLocation.hizb(
          _parsePathInt(state.pathParameters, 'hizbNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'page/:mushafId/:pageNumber',
      builder: (context, state) => MushafReaderScreen(
        key: ValueKey(state.matchedLocation),
        mushafId: _parsePathInt(state.pathParameters, 'mushafId'),
        initialPageNumber: _parsePathInt(state.pathParameters, 'pageNumber'),
      ),
    ),
  ];
}

/// The shell branches that carry [quranLocationRoutes] under their root,
/// so a location opens in the tab that asked for it.
const quranLocationBranchRoots = {'home', 'memorize', 'quran'};

/// The first path segment of each [quranLocationRoutes] route.
const _locationKinds = {'surah', 'ayah', 'ayah-range', 'juz', 'hizb', 'page'};

/// Whether [path] is a Quran location route (a reader or Mushaf screen) in
/// any branch, e.g. `/home/page/1/23`.
bool isQuranLocationPath(String path) {
  final segments = Uri.tryParse(path)?.pathSegments ?? const [];
  return segments.length >= 2 &&
      quranLocationBranchRoots.contains(segments[0]) &&
      _locationKinds.contains(segments[1]);
}

/// The one function every Quran index result (and, later, search results,
/// bookmarks, deep links) should call to open a [QuranLocation] — per this
/// milestone's "every index result should route through `QuranLocation`...
/// without screen-specific routing hacks" requirement.
///
/// The location opens on top of the screen that asked for it, in that
/// screen's own tab (Home, Memorize or Quran), so back returns there.
/// From a reader or Mushaf screen it replaces that screen instead of
/// stacking another; from any other tab it opens in the Quran tab.
void goToQuranLocation(BuildContext context, QuranLocation location) {
  final kindPath = switch (location) {
    QuranLocationSurah(:final surahNo) => 'surah/$surahNo',
    QuranLocationAyah(:final chapterNo, :final verseNo) =>
      'ayah/$chapterNo/$verseNo',
    QuranLocationAyahRange(
      :final chapterNo,
      :final fromVerseNo,
      :final toVerseNo,
    ) =>
      'ayah-range/$chapterNo/$fromVerseNo/$toVerseNo',
    QuranLocationJuz(:final juzNo) => 'juz/$juzNo',
    QuranLocationHizb(:final hizbNo) => 'hizb/$hizbNo',
    QuranLocationPage(:final mushafId, :final pageNumber) =>
      'page/$mushafId/$pageNumber',
  };
  final router = GoRouter.of(context);
  // The topmost screen, a pushed one included.
  final current = router.state.uri.path;
  final segments = Uri.tryParse(current)?.pathSegments ?? const [];
  final root =
      segments.isNotEmpty && quranLocationBranchRoots.contains(segments[0])
      ? '/${segments[0]}'
      : AppRoutes.quran;
  final path = '$root/$kindPath';
  if (isQuranLocationPath(current)) {
    router.replace(path);
  } else {
    router.push(path);
  }
}
