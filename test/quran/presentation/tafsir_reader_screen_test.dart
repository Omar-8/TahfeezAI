import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/routing/app_routes.dart';
import 'package:tahfeez_ai/core/routing/tafsir_routing.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/presentation/tafsir_reader_screen.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';

import '../quran_test_fixtures.dart';
import '../translation_tafsir_test_fixtures.dart';

void main() {
  Widget wrap(
    QuranDatabase db,
    TafsirDatabase tafsirDb, {
    String? activeTafsirId,
  }) {
    final router = GoRouter(
      initialLocation: '${AppRoutes.tafsir}/1/1',
      routes: [
        ...tafsirRoutes(),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const TafsirReaderScreen(chapterNo: 1, verseNo: 1),
        ),
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        tafsirDatabaseProvider.overrideWith((ref) => tafsirDb),
        if (activeTafsirId != null)
          tafsirSelectionControllerProvider.overrideWith(
            () => _FixedActiveTafsir(activeTafsirId),
          ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows an install hint with no active tafsir', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);

    await tester.pumpWidget(wrap(db, tafsirDb));
    await tester.pumpAndSettle();

    expect(find.textContaining('Install and select a tafsir'), findsOneWidget);
  });

  testWidgets('shows the active tafsir\'s commentary and source', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(wrap(db, tafsirDb, activeTafsirId: testTafsirId));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test commentary for verse 1'), findsOneWidget);
    expect(find.textContaining('Test Tafsir'), findsOneWidget);
  });

  testWidgets('next steps to the following verse', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(wrap(db, tafsirDb, activeTafsirId: testTafsirId));
    await tester.pumpAndSettle();

    expect(find.text('Tafsir · 1:1'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Tafsir · 1:2'), findsOneWidget);
    expect(find.textContaining('Test commentary for verse 2'), findsOneWidget);
  });
}

class _FixedActiveTafsir extends TafsirSelectionController {
  _FixedActiveTafsir(this._fixed);

  final String _fixed;

  @override
  String? build() => _fixed;
}
