import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/app_routes.dart';
import 'package:tahfeez_ai/core/routing/quran_location_routing.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/search/presentation/search_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/search_index_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/search_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

import 'package:tahfeez_ai/core/ui/first_run.dart';

void main() {
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup.read(browserStorageProvider).remove('search.history');
    await cleanup.read(browserStorageProvider).remove('search.filters');
    cleanup.dispose();
  });

  Widget wrap(
    QuranDatabase db,
    TranslationDatabase translationDb,
    SearchIndexDatabase indexDb,
  ) {
    // `goToQuranLocation` always builds paths under `AppRoutes.quran`, so
    // the test router mounts `quranLocationRoutes()` there too, matching
    // `reader_mushaf_mode_switch_test.dart`'s established pattern.
    final router = GoRouter(
      initialLocation: AppRoutes.search,
      routes: [
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoutes.quran,
          builder: (context, state) => const Scaffold(body: Text('Quran root')),
          routes: quranLocationRoutes(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        firstRunPromptsProvider.overrideWithValue(false),
        quranDatabaseProvider.overrideWith((ref) => db),
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        searchIndexDatabaseProvider.overrideWith((ref) => indexDb),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('shows an unavailable state with no dataset installed', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final translationDb = TranslationDatabase(NativeDatabase.memory());
    addTearDown(translationDb.close);
    final indexDb = SearchIndexDatabase(NativeDatabase.memory());
    addTearDown(indexDb.close);

    await tester.pumpWidget(wrap(db, translationDb, indexDb));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "This will appear automatically once a Qur'an dataset is added to the app.",
      ),
      findsOneWidget,
    );
  });

  group('with an installed synthetic dataset', () {
    late QuranDatabase db;
    late TranslationDatabase translationDb;
    late SearchIndexDatabase indexDb;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      translationDb = TranslationDatabase(NativeDatabase.memory());
      indexDb = SearchIndexDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      await translationDb.close();
      await indexDb.close();
    });

    testWidgets('shows recent-search hints when the query is empty', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try a verse'), findsOneWidget);
    });

    testWidgets('typing a query shows matching Surah and Arabic results', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'lafz');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text("Qur'an text"), findsOneWidget);
      expect(find.text('1:1'), findsWidgets);
    });

    testWidgets('a quick-link verse query navigates to that verse', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1:3');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Go to 1:3'), findsOneWidget);
      await tester.tap(find.text('Go to 1:3'));
      await tester.pumpAndSettle();

      // The app bar title now shows the live Mushaf page's Surah/page/Juz
      // (once resolved), not a plain "Ayah 1:3" string.
      expect(find.text('Test Chapter One'), findsWidgets);
      expect(find.textContaining('Page 1'), findsOneWidget);
    });

    testWidgets('a no-match query shows the empty state', (tester) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzznomatch');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.textContaining('No results for'), findsOneWidget);
    });

    testWidgets('running a search records it in history', (tester) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1:3');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to 1:3'));
      await tester.pumpAndSettle();

      // Navigate back to the search screen to check history was recorded.
      // Re-pump the search screen fresh to observe persisted state.
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      expect(find.text('1:3'), findsOneWidget);
    });

    testWidgets('the filter sheet toggles Arabic text search', (tester) async {
      await tester.pumpWidget(wrap(db, translationDb, indexDb));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Arabic Qur'an text"));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'lafz');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text("Qur'an text"), findsNothing);
    });
  });
}
