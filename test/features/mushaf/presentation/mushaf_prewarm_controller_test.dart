// Proves MushafPagePrewarmController's actual behavioral contract at the
// provider level (no widget tree needed -- every assertion here reads
// straight off ProviderContainer, exactly what a "swipe" would see).
//
// This does NOT, and cannot, prove real scroll performance -- see
// docs/MUSHAF_RENDERING.md's "Known limitations": that requires a real
// device in profile/release mode. What this DOES prove: the prewarm
// pipeline's ordering, deduplication, staleness-safety, and cache-window
// bookkeeping are all correct as implemented, using the exact same
// keepAlive providers production code reads from.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_word_measurer.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_layout_providers.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_prewarm_controller.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

/// Counts real shaping/measurement calls -- the same technique
/// `mushaf_layout_providers_test.dart` and `mushaf_page_layout_engine_test.dart`
/// already use to prove "no shaping happened," reused here so a prewarm
/// call's cost can be told apart from a later read that should be free.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranDatabase db;
  late _CountingMeasurer measurer;
  late ProviderContainer container;

  const width = 400.0;
  const height = 600.0;

  setUp(() async {
    db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    measurer = _CountingMeasurer(const TextPainterWordMeasurer());
    container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        mushafPageLayoutEngineProvider.overrideWith(
          (ref) => MushafPageLayoutEngine(measurer: measurer),
        ),
      ],
    );
  });

  tearDown(() async {
    // Drains any still-in-flight priority-3 (fire-and-forget) work before
    // disposing -- otherwise a background prewarm from *this* test can
    // still be running against an already-closed database once the next
    // test's `setUp` replaces `db`/`container`, throwing an error that
    // Dart's test framework can attribute to the wrong test entirely.
    await container
        .read(mushafPagePrewarmControllerProvider.notifier)
        .debugSettleForTest();
    container.dispose();
    await db.close();
  });

  MushafPageRenderModel? renderModelFor(int pageNumber) {
    return container.read(
      mushafPageRenderModelProvider(
        mushafId: mushafTestMushafId,
        pageNumber: pageNumber,
        availableWidth: width,
        availableHeight: height,
        fontFamily: null,
      ),
    );
  }

  test("page N+1's render model is built during prewarm -- before navigation "
      'ever reaches it, not lazily on arrival', () async {
    final controller = container.read(
      mushafPagePrewarmControllerProvider.notifier,
    );

    await controller.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 1,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );

    final callsAfterPrewarm = measurer.calls;
    expect(callsAfterPrewarm, greaterThan(0));

    // The "swipe" itself: reading page 2's render model exactly the way
    // MushafPageView does. If this were still unbuilt, reading it here
    // would trigger fresh shaping (new measurer calls) on this call --
    // i.e. on the destination page's own frame, the exact cost this
    // feature exists to eliminate.
    final page2 = renderModelFor(2);
    expect(page2, isNotNull);
    expect(page2!.pageNumber, 2);
    expect(
      measurer.calls,
      callsAfterPrewarm,
      reason:
          "reading page 2's already-prewarmed render model must not "
          'trigger any new shaping',
    );
  });

  test('concurrent prewarm requests for the same page share one in-flight '
      'Future and shape exactly once', () async {
    final futureA = container.read(
      mushafPageRenderModelPrewarmProvider(
        mushafId: mushafTestMushafId,
        pageNumber: 3,
        availableWidth: width,
        availableHeight: height,
      ).future,
    );
    final futureB = container.read(
      mushafPageRenderModelPrewarmProvider(
        mushafId: mushafTestMushafId,
        pageNumber: 3,
        availableWidth: width,
        availableHeight: height,
      ).future,
    );

    final results = await Future.wait([futureA, futureB]);
    expect(results[0], isNotNull);
    // The exact same cached instance, not two independently-shaped
    // equal-but-distinct objects -- proof of one shared computation.
    expect(identical(results[0], results[1]), isTrue);
  });

  test('repeated prewarmAround calls for an unchanged current page (as a '
      'rebuilding widget would produce) do not re-shape anything', () async {
    final controller = container.read(
      mushafPagePrewarmControllerProvider.notifier,
    );

    await controller.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 2,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );
    final callsAfterFirst = measurer.calls;
    expect(callsAfterFirst, greaterThan(0));

    await controller.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 2,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );

    expect(
      measurer.calls,
      callsAfterFirst,
      reason:
          'every page in this unchanged window is already cached, so '
          'a repeated call must be a pure no-op cost-wise',
    );
  });

  test('a rapid multi-page swipe (1 -> 3 before page 1\'s own prewarm '
      'settles) never associates the wrong page\'s content with page 3, '
      'and page 3 ends up correctly warmed', () async {
    final controller = container.read(
      mushafPagePrewarmControllerProvider.notifier,
    );

    // Deliberately not awaited between calls -- simulates the user
    // swiping through page 1 to page 3 before the first call's
    // lower-priority tiers finish.
    final firstCall = controller.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 1,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );
    final secondCall = controller.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 3,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );

    await Future.wait([firstCall, secondCall]);
    await controller.debugSettleForTest();

    // Every page's render model, if present at all, must report its
    // own correct page number and its own real tokens -- structurally
    // impossible to get wrong here (each is its own family-keyed cache
    // entry), but asserted explicitly per the "never associate page N
    // with page N+1" requirement.
    for (final page in [1, 2, 3, 4, 5]) {
      final model = renderModelFor(page);
      if (model == null) continue;
      expect(model.pageNumber, page);
    }

    final page3 = renderModelFor(3);
    expect(
      page3,
      isNotNull,
      reason: 'the final navigation target must end up warmed',
    );
  });

  test(
    "the render-model cache stays within the controller's configured "
    'window around the current page, evicting pages that fall outside it',
    () async {
      final controller = container.read(
        mushafPagePrewarmControllerProvider.notifier,
      );

      // An artificially large `totalPages` so the window (radius 2) is
      // meaningfully smaller than the whole book, making eviction
      // observable -- the fixture's own 5 real pages are enough to
      // populate/evict within.
      await controller.prewarmAround(
        mushafId: mushafTestMushafId,
        currentPage: 1,
        totalPages: 100,
        availableWidth: width,
        availableHeight: height,
      );
      await controller.debugSettleForTest();
      expect(controller.warmedPagesForTest, {1, 2, 3});

      // Move far enough that page 1's cache entry must be evicted.
      await controller.prewarmAround(
        mushafId: mushafTestMushafId,
        currentPage: 5,
        totalPages: 100,
        availableWidth: width,
        availableHeight: height,
      );
      await controller.debugSettleForTest();

      expect(
        controller.warmedPagesForTest,
        {3, 4, 5, 6, 7},
        reason:
            'only [currentPage-2, currentPage+2] should remain tracked -- '
            'page 1 and 2 fell outside the window around page 5',
      );
      // `invalidate` doesn't make a page permanently unavailable -- it
      // discards the cached instance, so the *next* read must redo the
      // real shaping work (a fresh measurer call), unlike a genuinely
      // still-cached page. That extra cost on demand, rather than a
      // permanent `null`, is the actual, correct meaning of "evicted."
      final callsBeforeRereading = measurer.calls;
      final page1Again = renderModelFor(1);
      expect(page1Again, isNotNull);
      expect(
        measurer.calls,
        greaterThan(callsBeforeRereading),
        reason:
            "page 1's cached render model must actually have been "
            'discarded -- reading it again after eviction should require '
            'fresh shaping, not return a still-cached instance',
      );
    },
  );

  test('word hit-test rectangles on a prewarmed page are identical to a '
      "freshly-built page's -- prewarming changes when shaping happens, "
      'never what it produces', () async {
    final prewarmedController = container.read(
      mushafPagePrewarmControllerProvider.notifier,
    );
    await prewarmedController.prewarmAround(
      mushafId: mushafTestMushafId,
      currentPage: 2,
      totalPages: 5,
      availableWidth: width,
      availableHeight: height,
    );

    final prewarmed = renderModelFor(3);
    expect(prewarmed, isNotNull);
    final prewarmedTextLines = prewarmed!.lines
        .whereType<MushafQuranTextLineRenderModel>()
        .toList();
    expect(prewarmedTextLines, isNotEmpty);
    final prewarmedRects = [
      for (final line in prewarmedTextLines)
        for (final rect in line.tokenRects) rect.rect,
    ];
    expect(prewarmedRects, isNotEmpty);

    // A second, independent container with no prewarming at all -- a
    // "fresh" build of the same page, same inputs.
    final freshDb = QuranDatabase(NativeDatabase.memory());
    addTearDown(freshDb.close);
    await const QuranDatasetImporter().import(
      freshDb,
      buildMushafTestPayload(),
    );
    final freshContainer = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => freshDb),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
      ],
    );
    addTearDown(freshContainer.dispose);

    // Mirrors what `MushafPageView` itself does before ever reading the
    // render-model provider: wait for the page's real data to resolve
    // first. Reading it synchronously beforehand would just observe the
    // provider's own "still loading" `null` state, not a real build.
    await freshContainer.read(
      mushafPageDataProvider(mushafTestMushafId, 3).future,
    );

    final fresh = freshContainer.read(
      mushafPageRenderModelProvider(
        mushafId: mushafTestMushafId,
        pageNumber: 3,
        availableWidth: width,
        availableHeight: height,
        fontFamily: null,
      ),
    );
    expect(fresh, isNotNull);
    final freshRects = [
      for (final line
          in fresh!.lines.whereType<MushafQuranTextLineRenderModel>())
        for (final rect in line.tokenRects) rect.rect,
    ];

    expect(freshRects, prewarmedRects);
  });
}
