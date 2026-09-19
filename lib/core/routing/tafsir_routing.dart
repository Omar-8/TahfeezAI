import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../quran/presentation/tafsir_reader_screen.dart';
import 'app_routes.dart';

/// The Tafsir reader's `go_router` route — a top-level destination (not
/// nested under `AppRoutes.quran`, since it is not a `QuranLocation`
/// variant, just a chapter+verse-scoped screen reachable from the reader).
/// Like `quran_location_routing.dart`, this file is `core/routing`'s
/// documented exception to `docs/ARCHITECTURE.md` §1's "core never depends
/// on a feature" rule.
List<RouteBase> tafsirRoutes() {
  return [
    GoRoute(
      path: '${AppRoutes.tafsir}/:chapterNo/:verseNo',
      builder: (context, state) => TafsirReaderScreen(
        chapterNo: int.parse(state.pathParameters['chapterNo']!),
        verseNo: int.parse(state.pathParameters['verseNo']!),
      ),
    ),
  ];
}

/// Opens the tafsir reader as a new destination on top of the current
/// screen (so the back button returns here) — the entry point every
/// "Tafsir" action (the reader's verse action bar, the word detail sheet)
/// should call, mirroring `goToQuranLocation`'s role for `QuranLocation`s.
/// The tafsir reader's own previous/next navigation replaces its route
/// directly (`lib/quran/presentation/tafsir_reader_screen.dart`) rather
/// than going through this helper, so paging through many verses does not
/// grow the back stack by one screen per step.
void openTafsirReader(
  BuildContext context, {
  required int chapterNo,
  required int verseNo,
}) {
  GoRouter.of(context).push('${AppRoutes.tafsir}/$chapterNo/$verseNo');
}
