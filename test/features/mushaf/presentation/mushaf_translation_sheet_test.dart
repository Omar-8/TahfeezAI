import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_translation_sheet.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/application/translation_selection_controller.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../../../quran/translation_tafsir_test_fixtures.dart';
import '../mushaf_test_fixtures.dart';

void main() {
  Widget wrap(
    QuranDatabase db,
    TranslationDatabase translationDb, {
    List<String> activeSlugs = const [],
  }) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        if (activeSlugs.isNotEmpty)
          translationSelectionControllerProvider.overrideWith(
            () => _FixedActiveTranslations(activeSlugs),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMushafTranslationSheet(
                context,
                mushafId: mushafTestMushafId,
                pageNumber: 1,
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows an empty state with no active translations', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    final translationDb = TranslationDatabase(NativeDatabase.memory());
    addTearDown(translationDb.close);

    await tester.pumpWidget(wrap(db, translationDb));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No active translations'), findsOneWidget);
  });

  testWidgets('shows each ayah on the page with its active translation text', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    final translationDb = TranslationDatabase(NativeDatabase.memory());
    addTearDown(translationDb.close);
    final container = ProviderContainer(
      overrides: [
        translationDatabaseProvider.overrideWith((ref) => translationDb),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(translationRepositoryProvider)
        .installTranslation(
          buildTestTranslationBook(),
          buildTestTranslationVerses(),
        );

    await tester.pumpWidget(
      wrap(db, translationDb, activeSlugs: [testTranslationSlug]),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('1:1'), findsOneWidget);
    expect(find.textContaining('Test translation for verse 1'), findsOneWidget);
  });
}

class _FixedActiveTranslations extends TranslationSelectionController {
  _FixedActiveTranslations(this._fixed);

  final List<String> _fixed;

  @override
  List<String> build() => _fixed;
}
