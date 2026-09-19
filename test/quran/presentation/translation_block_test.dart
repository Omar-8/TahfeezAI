import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';
import 'package:tahfeez_ai/quran/presentation/translation_block.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../quran_test_fixtures.dart';

void main() {
  const verseText = TranslationVerseText(
    slug: 'test',
    chapterNo: 1,
    verseNo: 1,
    text: 'Some translated text [1] with a marker.',
    footnotes: [TranslationFootnote(marker: 1, text: 'Explains the marker.')],
    crossReferences: [(chapterNo: 1, verseNo: 2)],
  );

  Widget wrap(Widget child, QuranDatabase db) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('renders the translation text and author attribution', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      wrap(
        const TranslationBlock(verseText: verseText, authorName: 'Jane Doe'),
        db,
      ),
    );

    expect(find.textContaining('Some translated text'), findsOneWidget);
    expect(find.text('— Jane Doe'), findsOneWidget);
  });

  testWidgets('tapping a footnote marker shows its text', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      wrap(
        const TranslationBlock(verseText: verseText, authorName: 'Jane Doe'),
        db,
      ),
    );

    await tester.tap(find.text('[1]'));
    await tester.pumpAndSettle();

    expect(find.text('Explains the marker.'), findsOneWidget);
  });

  testWidgets(
    'tapping a cross-reference chip opens the quick reference sheet',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      await tester.pumpWidget(
        wrap(
          const TranslationBlock(verseText: verseText, authorName: 'Jane Doe'),
          db,
        ),
      );

      await tester.tap(find.text('1:2'));
      await tester.pumpAndSettle();

      expect(find.text('Go to verse'), findsOneWidget);
    },
  );
}
