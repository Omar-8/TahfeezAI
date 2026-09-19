import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

/// A visual/golden test for [MushafPageView] — the milestone's explicit
/// "create visual/golden tests for representative pages" requirement.
///
/// This locks in the *rendering mechanism* (the `CustomPainter`-based line
/// renderer, chapter-header/Bismillah markers, page footer) against
/// regression, using Flutter's deterministic test-font fallback (no real
/// fonts loaded, so pixel output is stable across machines/CI). It is
/// deliberately just one representative page, not five: with only
/// synthetic filler words standing in for real Quran text and no real
/// script/font selected yet (`docs/ARCHITECTURE.md` §11d), five separate
/// pixel goldens would mostly be re-testing the same mechanism five times
/// rather than adding real Mushaf-fidelity coverage — the five named
/// scenarios (opening chapter, chapter beginning, mid-chapter, transition,
/// final page) are instead covered as layout-invariant tests
/// (`mushaf_pages_layout_test.dart`), which is where their real
/// distinguishing value (line count, structure, centering) lives.
void main() {
  testWidgets('MushafPageView renders page 1 consistently', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: MushafPageView(
                mushafId: mushafTestMushafId,
                pageNumber: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MushafPageView),
      matchesGoldenFile('goldens/mushaf_page_1.png'),
    );
  });
}
