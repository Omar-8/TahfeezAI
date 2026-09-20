import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_text_boldness_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_text_boldness.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_word_measurer.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_layout_providers.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

/// Counts real measurements, so a test can prove a rebuild did or didn't
/// redo the (expensive, real-font-shaping) per-page layout pass.
class _CountingMeasurer implements MushafWordMeasurer {
  _CountingMeasurer(this._real);
  final MushafWordMeasurer _real;
  int calls = 0;

  @override
  double measure(String text, double fontSize, {String? fontFamily}) {
    calls++;
    return _real.measure(text, fontSize, fontFamily: fontFamily);
  }
}

/// Rebuilds its subtree on demand via [bump], with nothing Mushaf-related
/// in its own state -- an "ancestor widget rebuilds for a reason that has
/// nothing to do with Quran layout" stand-in for real cases like a toolbar
/// visibility change or unrelated app chrome state.
class _UnrelatedRebuildHarness extends StatefulWidget {
  const _UnrelatedRebuildHarness({super.key, required this.child});
  final Widget child;

  @override
  State<_UnrelatedRebuildHarness> createState() =>
      _UnrelatedRebuildHarnessState();
}

class _UnrelatedRebuildHarnessState extends State<_UnrelatedRebuildHarness> {
  int _unrelatedCounter = 0;

  void bump() => setState(() => _unrelatedCounter++);

  @override
  Widget build(BuildContext context) {
    // `_unrelatedCounter` is read here purely so this build method has a
    // reason to differ each time -- the point being tested is that
    // `MushafPageView` below it still rebuilds (it is not `const`) without
    // re-shaping anything.
    return Padding(
      padding: EdgeInsets.only(top: _unrelatedCounter.isEven ? 0 : 0),
      child: widget.child,
    );
  }
}

void main() {
  testWidgets('an ancestor rebuild for a reason unrelated to Quran layout (app '
      'chrome, unrelated Riverpod state, ...) does not re-run the per-page '
      'shaping pass -- the real cost this memoization exists to avoid, '
      'since it shapes every line with a real TextPainter', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    addTearDown(db.close);

    final measurer = _CountingMeasurer(const TextPainterWordMeasurer());
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        mushafPageLayoutEngineProvider.overrideWith(
          (ref) => MushafPageLayoutEngine(measurer: measurer),
        ),
      ],
    );
    addTearDown(container.dispose);

    final harnessKey = GlobalKey<_UnrelatedRebuildHarnessState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: _UnrelatedRebuildHarness(
              key: harnessKey,
              child: const SizedBox(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(measurer.calls, greaterThan(0));
    final callsAfterFirstBuild = measurer.calls;

    // Force the ancestor (and therefore `MushafPageView`, its
    // non-`const` descendant) to rebuild, for a reason with nothing to
    // do with Mushaf/Quran state at all.
    harnessKey.currentState!.bump();
    await tester.pumpAndSettle();

    expect(
      measurer.calls,
      callsAfterFirstBuild,
      reason:
          'the page rebuilt (ancestor state changed) but its render '
          'model was cached, so no new shaping calls should have '
          'happened',
    );
  });

  testWidgets(
    'changing the Mushaf text boldness preference updates the currently '
    'visible page immediately (a genuinely new render model, not the '
    'cached one) without needing an app restart',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(db, buildMushafTestPayload());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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

      const providerArgs = (
        mushafId: mushafTestMushafId,
        pageNumber: 1,
        availableWidth: 360.0,
        availableHeight: 640.0,
      );
      final beforeModel = container.read(
        mushafPageRenderModelProvider(
          mushafId: providerArgs.mushafId,
          pageNumber: providerArgs.pageNumber,
          availableWidth: providerArgs.availableWidth,
          availableHeight: providerArgs.availableHeight,
        ),
      );
      expect(beforeModel, isNotNull);
      final beforeQuranLine = beforeModel!.lines
          .whereType<MushafQuranTextLineRenderModel>()
          .first;
      // Medium is the default, which already has a stroke pass (0.30 --
      // see MushafTextBoldness's doc comment); the directly-checkable
      // fact this test cares about is the *instance* identity below.
      expect(
        container.read(mushafTextBoldnessControllerProvider),
        MushafTextBoldness.medium,
      );
      expect(beforeQuranLine.strokePainter, isNotNull);

      await container
          .read(mushafTextBoldnessControllerProvider.notifier)
          .setBoldness(MushafTextBoldness.bold);
      await tester.pumpAndSettle();

      final afterModel = container.read(
        mushafPageRenderModelProvider(
          mushafId: providerArgs.mushafId,
          pageNumber: providerArgs.pageNumber,
          availableWidth: providerArgs.availableWidth,
          availableHeight: providerArgs.availableHeight,
        ),
      );
      expect(afterModel, isNotNull);
      expect(
        identical(beforeModel, afterModel),
        isFalse,
        reason:
            'MushafPagePainter.shouldRepaint only fires on a genuinely '
            'new renderModel instance -- an unchanged cached instance '
            'would silently never repaint the live page',
      );
      final afterQuranLine = afterModel!.lines
          .whereType<MushafQuranTextLineRenderModel>()
          .first;
      expect(afterQuranLine.strokePainter, isNotNull);
      expect(
        identical(beforeQuranLine.strokePainter, afterQuranLine.strokePainter),
        isFalse,
        reason:
            'Bold (0.40) must genuinely re-shape the stroke pass, not '
            'reuse Medium\'s (0.30) cached one',
      );
      // Line geometry itself is unaffected by the boldness change -- only
      // the paint layer differs.
      expect(afterQuranLine.painter!.width, beforeQuranLine.painter!.width);
      expect(afterQuranLine.paintOffset, beforeQuranLine.paintOffset);
    },
  );
}
