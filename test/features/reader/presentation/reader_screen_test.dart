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
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

/// This whole file exercises the verse-by-verse body specifically, so every
/// test fixes the reader mode rather than relying on
/// [ReaderModePreferenceController]'s real default (`ReaderMode.mushaf`,
/// per product direction) or its real, process-wide persisted state.
class _FixedReaderMode extends ReaderModePreferenceController {
  _FixedReaderMode(this._fixed);
  final ReaderMode _fixed;
  @override
  ReaderMode build() => _fixed;
}

/// Continuous scrolling (auto-loading the next chapter near the end of the
/// current one) is a real, independent feature this file's tests don't mean
/// to exercise -- they're about rendering a single Surah's own body. Fixed
/// off so a test that scrolls through a short Surah (whose total scrollable
/// range is well under continuous scrolling's own "near the end" distance,
/// by design intentionally aggressive for short remaining content) doesn't
/// incidentally cascade into loading chapter after chapter while a test
/// merely scrolls to check its own verses render.
class _NoContinuousScrolling extends ContinuousScrollingPreferenceController {
  @override
  bool build() => false;
}

void main() {
  Widget wrap(
    QuranDatabase db, {
    QuranLocation location = const QuranLocation.surah(1),
  }) {
    return ProviderScope(
      overrides: [
        verseByVerseModeEnabledProvider.overrideWithValue(true),
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
        readerModePreferenceControllerProvider.overrideWith(
          () => _FixedReaderMode(ReaderMode.verseByVerse),
        ),
        continuousScrollingPreferenceControllerProvider.overrideWith(
          () => _NoContinuousScrolling(),
        ),
        // `TranslationLibraryController` (opened via "Reader options" ->
        // "Translations") always queries `translationRepositoryProvider`
        // unconditionally, unlike `ReaderSession`'s active-slugs-gated
        // lookup — so this must never fall through to the real
        // drift_flutter connection in tests either.
        translationDatabaseProvider.overrideWith(
          (ref) => TranslationDatabase(NativeDatabase.memory()),
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
        home: ReaderScreen(location: location),
      ),
    );
  }

  testWidgets('shows an unavailable state with no dataset installed', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This will appear automatically once a Quran dataset is added to the app.',
      ),
      findsOneWidget,
    );
  });

  group('with an installed synthetic dataset', () {
    late QuranDatabase db;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
    });

    tearDown(() => db.close());

    testWidgets('renders the chapter info card and every verse', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Appears twice: the chapter-info card's own title, and the app bar's
      // live Mushaf-page title (Surah name), which resolves to the same
      // Surah once the current position's Mushaf page loads.
      expect(find.text('Test Chapter One'), findsNWidgets(2));
      expect(find.text('Meccan · 7 ayahs'), findsOneWidget);
      // The list is lazily built (`ListView.builder`), so scroll to prove
      // every verse -- not just the first screenful -- actually loaded.
      for (var verse = 1; verse <= 7; verse++) {
        await tester.scrollUntilVisible(find.text('1:$verse'), 200);
        expect(find.text('1:$verse'), findsOneWidget);
      }
      // Arabic text visible by default (the fixture's synthetic word text),
      // rendered as individually tappable words (Milestone 8), not one
      // joined string.
      expect(find.text('lafz'), findsWidgets);
      expect(find.text('kalima'), findsWidgets);
    });

    testWidgets('tapping a word opens the word detail sheet', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('lafz').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ayah 1:1'), findsOneWidget);
      expect(
        find.textContaining('Install a word-by-word language pack'),
        findsOneWidget,
      );
    });

    // NOTE: this test persists "Arabic text visible = false" to the real
    // (process-wide) preferences store `ArabicTextVisiblePreferenceController`
    // reads from, which is not reset between tests — it must run after any
    // other test in this file that depends on Arabic text being visible by
    // default, or that later test will see it already hidden.
    testWidgets('the reader options sheet toggles Arabic text visibility', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.text('lafz'), findsWidgets);

      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Arabic text'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('lafz'), findsNothing);
    });

    testWidgets(
      'the reader options sheet Translations row opens the real translations sheet',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Reader options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Translations'));
        await tester.pumpAndSettle();

        expect(find.text('No translations available yet.'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the disabled Translation mode segment shows coming soon',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Translation — coming soon'));
        await tester.pumpAndSettle();

        expect(find.text('Coming soon'), findsOneWidget);
      },
    );

    testWidgets('tapping Play/Bookmark/Tafsir shows coming soon', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Play').first);
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets(
      'tapping a verse reference badge copies it and shows feedback',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.tap(find.text('1:2'));
        await tester.pumpAndSettle();

        expect(find.text('Copied 1:2'), findsOneWidget);
      },
    );

    testWidgets('long-press selects a verse and shows the selection bar', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('1:1'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Long-press (not tap) toggles a verse in/out of selection: tapping
      // the reference badge itself always copies (it has its own, nested
      // `onTap`), so extending selection needs the same gesture that
      // started it.
      await tester.longPress(find.text('1:2'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets(
      'sharing a selection opens a sheet with a working copy button',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('1:1'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Share'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1:1'), findsWidgets);
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets(
    'loads the containing chapter and titles it for an Ayah location',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);

      await tester.pumpWidget(
        wrap(db, location: const QuranLocation.ayah(1, 3)),
      );
      await tester.pumpAndSettle();

      // The app bar title now shows the live Mushaf page's Surah/page/Juz
      // (once resolved), not a plain "Ayah 1:3" string.
      expect(find.text('Test Chapter One'), findsWidgets);
      expect(find.textContaining('Page 1'), findsOneWidget);
      // The whole chapter loads (all 7 verses), not just verse 3. The
      // reader auto-scrolled to verse 3, so scroll up to verse 1 first,
      // then down through the rest, to visit every verse regardless of
      // where the initial scroll landed.
      await tester.scrollUntilVisible(find.text('1:1'), -200);
      expect(find.text('1:1'), findsOneWidget);
      for (var verse = 2; verse <= 7; verse++) {
        await tester.scrollUntilVisible(find.text('1:$verse'), 200);
        expect(find.text('1:$verse'), findsOneWidget);
      }
    },
  );
}
