import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_painter.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../mushaf_test_fixtures.dart';

/// Finds the first Quran-word token's on-screen center on the currently
/// rendered Mushaf page, by reading the real (already-shaped)
/// [MushafPageRenderModel] straight off the page's one [MushafPagePainter]
/// — the same real hit rectangles `MushafPageView`'s own `GestureDetector`
/// tests taps against, not a value this test guesses independently.
Offset _firstWordCenter(WidgetTester tester) {
  // The default 800x600 test surface can trip the two-page-spread
  // breakpoint, rendering two `MushafPageView`s (and so two
  // `MushafPagePainter`s) side by side -- the first is always page 1.
  final finder = find
      .byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MushafPagePainter,
      )
      .first;
  final painter =
      (tester.widget<CustomPaint>(finder).painter as MushafPagePainter);
  final topLeft = tester.getTopLeft(finder);
  for (final line in painter.renderModel.lines) {
    if (line is MushafQuranTextLineRenderModel && line.tokenRects.isNotEmpty) {
      return topLeft + line.tokenRects.first.rect.center;
    }
  }
  throw StateError('No Quran-text token found on this page to tap.');
}

/// Whether any node in the real semantics tree (rooted at [root]) carries
/// [label] — the painted Surah-header line's accessibility node is a
/// synthetic child `SemanticsNode` created directly by
/// [MushafPagePainter]'s `semanticsBuilder`, with no backing `Element`, so
/// `find.bySemanticsLabel` (which only inspects each `Element`'s own
/// `RenderObject.debugSemantics`) cannot see it — this walks the actual
/// tree instead.
bool _semanticsTreeHasLabel(SemanticsNode root, String label) {
  if (root.getSemanticsData().attributedLabel.string == label) return true;
  var found = false;
  root.visitChildren((child) {
    if (_semanticsTreeHasLabel(child, label)) found = true;
    return !found;
  });
  return found;
}

void main() {
  Widget wrap(QuranDatabase db, {int initialPageNumber = 1}) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        // `activeTranslationBooksProvider` (watched by the translation
        // sheet) reads `translationRepositoryProvider` unconditionally,
        // even with no active translations selected -- must never fall
        // through to the real drift_flutter connection in tests.
        translationDatabaseProvider.overrideWith(
          (ref) => TranslationDatabase(NativeDatabase.memory()),
        ),
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

    testWidgets("renders the opening chapter's name and the live page title", (
      tester,
    ) async {
      // Disposed explicitly at the end of this callback, not via
      // `addTearDown`: `testWidgets` runs its own end-of-test semantics
      // -handle check *before* `addTearDown` callbacks are flushed, so a
      // handle only released that way is reported as a leak.
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Only the app bar title is a real `Text` widget -- the on-page
      // Surah-header line is painted directly onto the page's one
      // `CustomPainter` canvas (never a separate widget per line), so
      // it's invisible to a widget-tree text finder by design.
      expect(find.text('Test Opening Chapter'), findsOneWidget);
      expect(find.textContaining('Page 1'), findsOneWidget);

      // A screen reader must still be told the chapter's name: the
      // painted header (whether the real decorative glyph or its
      // dev-only fallback) carries a real accessibility node whose label
      // is the localized name, never the glyph itself.
      final owner =
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner!;
      final root = owner.rootSemanticsNode!;
      expect(_semanticsTreeHasLabel(root, 'Test Opening Chapter'), isTrue);
      semantics.dispose();
    });

    testWidgets('tapping a word shows its ayah reference', (tester) async {
      // A wide viewport: `flutter_test`'s placeholder font renders every
      // glyph -- including a bare space -- as a full glyph-width box,
      // much wider than any real page font's actual (thin) space
      // character (confirmed against a real QCF page font directly: on
      // the order of a few percent of the font size). A narrow width
      // would make this specific synthetic fixture's denser lines
      // legitimately overflow under that placeholder-font quirk alone,
      // which has nothing to do with real-font correctness.
      tester.view.physicalSize = const Size(2400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // The exact center of a real token's hit rectangle, recovered from
      // the page's own already-shaped render model -- never a guessed
      // pixel offset.
      await tester.tapAt(_firstWordCenter(tester));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ayah 1:'), findsOneWidget);
      // The real word detail sheet (Milestone 8), not the old placeholder
      // SnackBar — honest about no word-by-word pack being installed.
      expect(
        find.textContaining('Install a word-by-word language pack'),
        findsOneWidget,
      );
    });

    testWidgets('swiping moves to the next page', (tester) async {
      // Force a phone-shaped viewport: `flutter_test`'s 800x600 default
      // surface is wide/short enough to trip `MushafPager`'s two-page
      // -spread breakpoint, which shows pages 1 and 2 side by side from
      // the very start -- "Page 2" would already be findable before any
      // swipe, masking whether swiping actually did anything.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 1'), findsOneWidget);
      expect(find.textContaining('Page 2'), findsNothing);

      // Neighboring pages are pre-built (not just the on-screen one) so a
      // swipe's landing page never pays for its layout pass only once
      // already visible -- a real, measurable contributor to Mushaf-mode
      // scroll jank otherwise.
      expect(
        tester.widget<PageView>(find.byType(PageView)).allowImplicitScrolling,
        isTrue,
      );

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 2'), findsOneWidget);
      // Only the app bar title is a real widget -- same reason as the
      // opening-chapter test above.
      expect(find.text('Test Long Chapter'), findsOneWidget);
    });

    testWidgets('the appearance sheet switches the page background', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();
      // "Reader options" now opens this screen's own small menu
      // (Appearance / Quran text boldness) rather than the appearance
      // picker directly.
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Quran text boldness'), findsOneWidget);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFF000000));
    });

    testWidgets(
      'the Translation & tafsir button opens the per-page translation sheet',
      (tester) async {
        await tester.pumpWidget(wrap(db));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Translation & tafsir'));
        await tester.pumpAndSettle();

        // No active translations selected in this test -- the sheet's own
        // honest empty state, not a crash or a silent no-op.
        expect(
          find.textContaining('No active translations to show'),
          findsOneWidget,
        );
      },
    );

    testWidgets('opens directly at the requested initial page', (tester) async {
      await tester.pumpWidget(wrap(db, initialPageNumber: 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 3'), findsOneWidget);
    });
  });
}
