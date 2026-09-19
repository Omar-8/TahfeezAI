import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/quran/presentation/quran_location_stub_screen.dart';
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
/// [QuranLocationPage] still opens [QuranLocationStubScreen]: Mushaf paging
/// is Milestone 7's job, and the reader has no page-based content model to
/// serve yet.
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
        location: QuranLocation.surah(
          _parsePathInt(state.pathParameters, 'surahNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'ayah/:chapterNo/:verseNo',
      builder: (context, state) => ReaderScreen(
        location: QuranLocation.ayah(
          _parsePathInt(state.pathParameters, 'chapterNo'),
          _parsePathInt(state.pathParameters, 'verseNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'ayah-range/:chapterNo/:fromVerseNo/:toVerseNo',
      builder: (context, state) => ReaderScreen(
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
        location: QuranLocation.juz(
          _parsePathInt(state.pathParameters, 'juzNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'hizb/:hizbNo',
      builder: (context, state) => ReaderScreen(
        location: QuranLocation.hizb(
          _parsePathInt(state.pathParameters, 'hizbNo'),
        ),
      ),
    ),
    GoRoute(
      path: 'page/:mushafId/:pageNumber',
      builder: (context, state) => QuranLocationStubScreen(
        location: QuranLocation.page(
          _parsePathInt(state.pathParameters, 'mushafId'),
          _parsePathInt(state.pathParameters, 'pageNumber'),
        ),
      ),
    ),
  ];
}

/// The one function every Quran index result (and, later, search results,
/// bookmarks, deep links) should call to open a [QuranLocation] — per this
/// milestone's "every index result should route through `QuranLocation`...
/// without screen-specific routing hacks" requirement.
void goToQuranLocation(BuildContext context, QuranLocation location) {
  final path = switch (location) {
    QuranLocationSurah(:final surahNo) => '${AppRoutes.quran}/surah/$surahNo',
    QuranLocationAyah(:final chapterNo, :final verseNo) =>
      '${AppRoutes.quran}/ayah/$chapterNo/$verseNo',
    QuranLocationAyahRange(
      :final chapterNo,
      :final fromVerseNo,
      :final toVerseNo,
    ) =>
      '${AppRoutes.quran}/ayah-range/$chapterNo/$fromVerseNo/$toVerseNo',
    QuranLocationJuz(:final juzNo) => '${AppRoutes.quran}/juz/$juzNo',
    QuranLocationHizb(:final hizbNo) => '${AppRoutes.quran}/hizb/$hizbNo',
    QuranLocationPage(:final mushafId, :final pageNumber) =>
      '${AppRoutes.quran}/page/$mushafId/$pageNumber',
  };
  GoRouter.of(context).go(path);
}
