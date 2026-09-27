import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/application/verse_mode_feature.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/reader/application/reader_preferences_controller.dart';
import 'package:tahfeez_ai/features/reader/domain/reader_mode.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';
import '../../mushaf/mushaf_test_fixtures.dart' as mushaf_fixtures;

class _FixedReaderMode extends ReaderModePreferenceController {
  _FixedReaderMode(this._fixed);
  final ReaderMode _fixed;
  @override
  ReaderMode build() => _fixed;
}

void main() {
  Widget wrap(
    QuranDatabase db, {
    ReaderMode initialMode = ReaderMode.verseByVerse,
  }) {
    return ProviderScope(
      overrides: [
        verseByVerseModeEnabledProvider.overrideWithValue(true),
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
        readerModePreferenceControllerProvider.overrideWith(
          () => _FixedReaderMode(initialMode),
        ),
      ],
      child: MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ReaderScreen(location: QuranLocation.surah(1)),
      ),
    );
  }

  testWidgets(
    'tapping the Mushaf mode segment switches in place to the Mushaf page at the current position',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Starts in verse-by-verse mode: the chapter-info card's subtitle is
      // real verse-by-verse-only chrome ("Test Chapter One" itself isn't
      // unique to this mode -- the Mushaf page's own Surah-header line
      // shows the same localized chapter name).
      expect(find.text('Meccan · 7 ayahs'), findsOneWidget);

      await tester.tap(find.byTooltip('Mushaf'));
      // Resolving the current position to a Mushaf page awaits two
      // repository queries before the page itself renders.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // No route push: still the same screen. The app bar title now shows
      // the live page's own Surah/page/Juz -- not the static entry
      // location -- so it says "Page 1" rather than "Surah 1".
      expect(find.textContaining('Page 1'), findsWidgets);
      // Verse-by-verse-only chrome is gone; Mushaf-only chrome is showing.
      expect(find.text('Meccan · 7 ayahs'), findsNothing);
      // The real per-page translation/tafsir sheet is reachable from here
      // (translation text never renders inside the printed 15-line body
      // itself, so this is its only route in Mushaf mode).
      expect(find.byTooltip('Translation & tafsir'), findsOneWidget);
      expect(find.byTooltip('Reader options'), findsOneWidget);
      // Surah 1's ayahs (1001-1007) are all on the fixture's page 1.
      expect(find.textContaining('Page 1'), findsWidgets);
    },
  );

  testWidgets(
    'switching back to verse-by-verse from Mushaf mode preserves reading position',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);

      await tester.pumpWidget(wrap(db, initialMode: ReaderMode.mushaf));
      await tester.pumpAndSettle();
      // Resolving the initial Mushaf page (this mode's real default) also
      // awaits repository queries.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 1'), findsWidgets);

      await tester.tap(find.byTooltip('Verse by verse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Back to verse-by-verse chrome, scrolled to the ayah the Mushaf
      // page was showing (Surah 1's own chapter-info card, at the top).
      expect(find.text('Meccan · 7 ayahs'), findsOneWidget);
      expect(find.byTooltip('Translation & tafsir'), findsNothing);
    },
  );

  testWidgets(
    "in Mushaf mode, the in-place Reader's own 'Reader options' sheet "
    "(mushaf_reader_options_sheet.dart) lists 'Appearance' -- the "
    "QPC-V2-specific 'Quran text boldness' setting was removed with that "
    'renderer (docs/QURAN_ENGINE_MIGRATION.md)',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);

      await tester.pumpWidget(wrap(db, initialMode: ReaderMode.mushaf));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
    },
  );

  testWidgets('switching to Mushaf mode from a non-opening Surah goes to that '
      "Surah's own page, not always page 1/Al-Fatiha -- a real bug: the "
      'resolved page was cached on first use and never refreshed on a later '
      'explicit switch, so every switch after the first replayed whatever '
      'page an earlier visit had landed on', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(
      db,
      mushaf_fixtures.buildMushafTestPayload(),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verseByVerseModeEnabledProvider.overrideWithValue(true),
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith(
            (ref) => mushaf_fixtures.mushafTestScriptCode,
          ),
          readerModePreferenceControllerProvider.overrideWith(
            () => _FixedReaderMode(ReaderMode.verseByVerse),
          ),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Surah 50 is the fixture's "plain mid-chapter page" -- Page 3,
          // nowhere near Al-Fatiha/Page 1.
          home: const ReaderScreen(location: QuranLocation.surah(50)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mushaf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 3'), findsWidgets);
    expect(find.textContaining('Page 1'), findsNothing);

    // Switch back and forth again -- the actual reported bug only
    // showed up from the *second* switch onward, since the first
    // switch's resolution used to get cached and replayed forever after.
    await tester.tap(find.byTooltip('Verse by verse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mushaf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 3'), findsWidgets);
    expect(find.textContaining('Page 1'), findsNothing);
  });

  testWidgets('swiping to a different Mushaf page, then switching back to '
      'verse-by-verse, follows the swiped-to page', (tester) async {
    // Force a phone-shaped viewport: `flutter_test`'s 800x600 default
    // surface is wide/short enough to trip `MushafPager`'s two-page
    // -spread breakpoint, which would show pages 1 and 2 side by side
    // from the very start -- masking whether a swipe actually changed
    // anything, since "Page 2" would already be findable either way.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(
      db,
      mushaf_fixtures.buildMushafTestPayload(),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verseByVerseModeEnabledProvider.overrideWithValue(true),
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith(
            (ref) => mushaf_fixtures.mushafTestScriptCode,
          ),
          readerModePreferenceControllerProvider.overrideWith(
            () => _FixedReaderMode(ReaderMode.mushaf),
          ),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ReaderScreen(location: QuranLocation.surah(1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 1'), findsWidgets);
    expect(find.textContaining('Page 2'), findsNothing);

    // 300px, not the full 390px viewport width: a fling distance close to
    // (or past) a full page width can overshoot by an extra page under
    // PageScrollPhysics' ballistic simulation -- this needs enough
    // distance to register as a deliberate one-page swipe with real
    // margin below that threshold, not exactly one viewport's width.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 2'), findsWidgets);

    await tester.tap(find.byTooltip('Verse by verse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Page 2 is the fixture's "beginning of a longer chapter" -- Surah 2
    // -- so verse-by-verse should follow the swipe there, not reopen
    // Surah 1 (the entry location) as if the swipe never happened. The
    // app bar title (never scrolled) is the reliable signal: it now
    // shows the live Mushaf page's own Surah/page/Juz once resolved --
    // "Test Long Chapter" / "Page 2" -- rather than a plain "Ayah 2:1"
    // string. The chapter-info card itself legitimately scrolls off-
    // screen and out of the lazy ListView's built range once the session
    // scrolls straight to the target ayah near the top of the viewport,
    // so it can't be checked directly here (confirmed by tracing every
    // intermediate value: the swiped-to page, resolved ayah, target
    // chapter, and session reload are all correct).
    expect(find.textContaining('Test Long Chapter'), findsWidgets);
    expect(find.textContaining('Page 2'), findsWidgets);
    expect(find.text('2:1'), findsOneWidget);
  });
}
