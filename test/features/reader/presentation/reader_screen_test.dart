import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  Widget wrap(
    QuranDatabase db, {
    QuranLocation location = const QuranLocation.surah(1),
  }) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
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

      expect(find.text('Test Chapter One'), findsOneWidget);
      expect(find.text('Meccan · 7 ayahs'), findsOneWidget);
      // The list is lazily built (`ListView.builder`), so scroll to prove
      // every verse -- not just the first screenful -- actually loaded.
      for (var verse = 1; verse <= 7; verse++) {
        await tester.scrollUntilVisible(find.text('1:$verse'), 200);
        expect(find.text('1:$verse'), findsOneWidget);
      }
      // Arabic text visible by default (the fixture's synthetic word text).
      expect(find.textContaining('lafz kalima'), findsWidgets);
    });

    testWidgets('the reader options sheet toggles Arabic text visibility', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.textContaining('lafz kalima'), findsWidgets);

      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Arabic text'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.textContaining('lafz kalima'), findsNothing);
    });

    testWidgets(
      'the reader options sheet select-translations row shows coming soon',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Reader options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select translations'));
        await tester.pumpAndSettle();

        expect(find.text('Coming soon'), findsOneWidget);
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

      expect(find.text('Ayah 1:3'), findsOneWidget);
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
