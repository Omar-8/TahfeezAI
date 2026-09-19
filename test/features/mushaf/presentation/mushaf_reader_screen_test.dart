import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

void main() {
  Widget wrap(QuranDatabase db, {int initialPageNumber = 1}) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
      ],
      child: MaterialApp(
        home: MushafReaderScreen(
          mushafId: mushafTestMushafId,
          initialPageNumber: initialPageNumber,
        ),
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

  group('with an installed synthetic Mushaf dataset', () {
    late QuranDatabase db;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    });

    tearDown(() => db.close());

    testWidgets('renders the opening chapter\'s name and page footer', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.text('Test Opening Chapter'), findsOneWidget);
      expect(find.textContaining('Page 1'), findsOneWidget);
    });

    testWidgets('tapping a word shows its ayah reference', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Page 1's first Quran-text line is line 3 (after the surah-header
      // and Bismillah lines). The first word in reading order (Arabic is
      // right-to-left) renders at the right edge of the line's box, so tap
      // near there rather than the exact center, which can land in an
      // inter-word gap.
      final rect = tester.getRect(
        find.byKey(const ValueKey('mushaf-page-1-line-3')),
      );
      await tester.tapAt(Offset(rect.right - 4, rect.center.dy));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ayah 1:'), findsOneWidget);
    });

    testWidgets('swiping moves to the next page', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 1'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 2'), findsOneWidget);
      expect(find.text('Test Long Chapter'), findsOneWidget);
    });

    testWidgets('the appearance sheet switches the page background', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFF000000));
    });

    testWidgets('opens directly at the requested initial page', (tester) async {
      await tester.pumpWidget(wrap(db, initialPageNumber: 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 3'), findsOneWidget);
    });
  });
}
