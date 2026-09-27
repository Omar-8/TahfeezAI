// Exercises MushafPager's web-only navigation/appearance additions: extra
// spacing and a border around each page of a two-page spread, mouse
// click-and-drag, left/right arrow-key navigation, and turning a mouse
// -wheel scroll into exactly one page change instead of a continuous
// free-scroll -- all gated behind `PlatformCapabilities.isWeb` so
// native/mobile behavior is provably untouched (asserted directly below by
// re-running several of the same gestures with `isWeb: false` and
// confirming they do nothing).
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/platform/platform_capabilities.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_pager.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

class _FakePlatformCapabilities implements PlatformCapabilities {
  const _FakePlatformCapabilities({required this.isWeb});

  @override
  final bool isWeb;

  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get supportsBackgroundAudioSession => false;
  @override
  bool get supportsHomeScreenWidgets => false;
  @override
  bool get supportsScheduledNotifications => false;
  @override
  bool get supportsNativeFileStorage => !isWeb;
}

// Stands in for a loaded engine page's published aspect ratio, without
// needing a real engine backend under test.
class _FixedAspectRatios extends MushafPageAspectRatios {
  _FixedAspectRatios(this.ratio);

  final double ratio;

  @override
  Map<int, double> build() => {
    for (var page = 1; page <= 5; page++) page: ratio,
  };
}

void main() {
  Future<QuranDatabase> buildDb() async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    return db;
  }

  Widget wrap(
    QuranDatabase db, {
    required bool isWeb,
    required ValueChanged<int> onPageChanged,
    double? pageAspectRatio,
  }) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        platformCapabilitiesProvider.overrideWithValue(
          _FakePlatformCapabilities(isWeb: isWeb),
        ),
        if (pageAspectRatio != null)
          mushafPageAspectRatiosProvider.overrideWith(
            () => _FixedAspectRatios(pageAspectRatio),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MushafPager(
            mushafId: mushafTestMushafId,
            pageCount: 5,
            initialPageNumber: 1,
            onPageChanged: onPageChanged,
          ),
        ),
      ),
    );
  }

  // Landscape and wide enough to trip the two-page-spread breakpoint
  // (`TahfeezBreakpoint.isAtLeastTablet && isLandscape && width > 700`).
  Future<void> useSpreadViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
  }

  // Narrow and portrait -- below the phone breakpoint, so single-page mode
  // always applies regardless of orientation. The default 800x600 test
  // surface is landscape and tablet-width, which would otherwise trip the
  // two-page spread and make page-index and page-number diverge.
  Future<void> useSinglePageViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets(
    'web: a two-page spread gets extra gutter spacing and a border around '
    'each page; native does not',
    (tester) async {
      final db = await buildDb();
      addTearDown(db.close);
      await useSpreadViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(db, isWeb: false, onPageChanged: (_) {}));
      await tester.pumpAndSettle();

      final borderedNative = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      );
      final gapNative = find.byWidgetPredicate(
        (w) => w is SizedBox && w.child is ColoredBox,
      );
      expect(borderedNative, findsNothing);
      expect(gapNative, findsNothing);

      await tester.pumpWidget(wrap(db, isWeb: true, onPageChanged: (_) {}));
      await tester.pumpAndSettle();

      final borderedWeb = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      );
      final gapWeb = find.byWidgetPredicate(
        (w) => w is SizedBox && w.child is ColoredBox,
      );
      // Both pages of the spread (page 1 and page 2) are bordered.
      expect(borderedWeb, findsNWidgets(2));
      expect(gapWeb, findsOneWidget);
    },
  );

  testWidgets(
    'web: the page frame is keyed to the engine page aspect ratio so the '
    'border hugs the printed page and never overflows its half of the '
    'spread; native is not wrapped',
    (tester) async {
      final db = await buildDb();
      addTearDown(db.close);
      await useSpreadViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pageViewport =
          tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.pumpWidget(
        wrap(db, isWeb: false, onPageChanged: (_) {}, pageAspectRatio: 0.7),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AspectRatio), findsNothing);

      await tester.pumpWidget(
        wrap(db, isWeb: true, onPageChanged: (_) {}, pageAspectRatio: 0.7),
      );
      await tester.pumpAndSettle();
      // Both pages of the spread are aspect-keyed, so each bordered frame
      // sizes to the printed page rather than the whole viewport box...
      final borderedWeb = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      );
      expect(borderedWeb, findsNWidgets(2));
      final labelByFrameDx = <double, String>{};
      for (final element in borderedWeb.evaluate()) {
        final frame = find.byWidgetPredicate(
          (w) => w is Container && identical(w, element.widget),
        );
        final rect = tester.getRect(frame);
        final deco = (element.widget as Container).decoration! as BoxDecoration;
        final borderWidth = (deco.border as Border?)?.top.width ?? 0;
        // ...the whole frame still stays inside the space actually available,
        // so the page can never be clipped at the outer edges of the spread.
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(pageViewport.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(pageViewport.height));
        // And the aspect-keyed *page box* inside that frame keeps the page's
        // true aspect -- that is what makes the border hug the printed page.
        final pageBox = tester.getRect(
          find.descendant(
            of: frame,
            matching: find.byKey(const ValueKey('mushaf-page-box')),
          ),
        );
        expect(pageBox.width / pageBox.height, closeTo(0.7, 0.001));
        // The small page number is printed at the very bottom, riding the
        // border rule.
        final label = find.descendant(
          of: frame,
          matching: find.byWidgetPredicate(
            (w) => w is Text && (w.data == '1' || w.data == '2'),
          ),
        );
        expect(label, findsOneWidget);
        labelByFrameDx[rect.center.dx] = tester.widget<Text>(label).data ?? '';
        final chipFinder = find.descendant(
          of: frame,
          matching: find.byKey(const ValueKey('mushaf-page-number-chip')),
        );
        final chipBox = tester.getRect(chipFinder);
        // The number chip is centred on the border rule...
        expect(chipBox.center.dx, closeTo(rect.center.dx, 1.0));
        expect(
          (chipBox.center.dy - (rect.bottom - borderWidth / 2)).abs(),
          lessThanOrEqualTo(borderWidth),
        );
        // ...is tall enough to *cover* the whole border stroke (rising above
        // it and reaching past the frame's bottom edge), so the rule reads
        // as cleanly cut where the number sits -- not just drawn over...
        expect(chipBox.top, lessThanOrEqualTo(rect.bottom - borderWidth));
        expect(chipBox.bottom, greaterThanOrEqualTo(rect.bottom));
        // ...and shares the frame's paper colour, so the covered rule looks
        // like a cut in the border rather than a floating label.
        final chipDeco =
            (tester.widget<Container>(chipFinder).decoration! as BoxDecoration);
        expect(chipDeco.color, deco.color);
      }
      // Each frame shows its own page's number, and the lower-numbered page
      // sits on the right (a Mushaf opens right-to-left, regardless of the
      // ambient text direction) -- so the left frame shows '2' and the right
      // frame shows '1'.
      expect(labelByFrameDx, hasLength(2));
      final minDx = labelByFrameDx.keys.reduce((a, b) => a < b ? a : b);
      final maxDx = labelByFrameDx.keys.reduce((a, b) => a > b ? a : b);
      expect(labelByFrameDx[minDx], '2');
      expect(labelByFrameDx[maxDx], '1');
    },
  );

  testWidgets(
    'web: left/right arrow keys navigate pages; native ignores them',
    (tester) async {
      final db = await buildDb();
      addTearDown(db.close);
      await useSinglePageViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final nativePages = <int>[];
      await tester.pumpWidget(
        wrap(db, isWeb: false, onPageChanged: nativePages.add),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(nativePages, isEmpty);

      final webPages = <int>[];
      await tester.pumpWidget(
        wrap(db, isWeb: true, onPageChanged: webPages.add),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(webPages, [2]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(webPages, [2, 1]);
    },
  );

  testWidgets(
    'web: mouse is an accepted drag device for the pager; native excludes '
    'it (Flutter\'s own default)',
    (tester) async {
      final db = await buildDb();
      addTearDown(db.close);
      await useSinglePageViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final nativePages = <int>[];
      await tester.pumpWidget(
        wrap(db, isWeb: false, onPageChanged: nativePages.add),
      );
      await tester.pumpAndSettle();

      final nativeContext = tester.element(find.byType(PageView));
      expect(
        ScrollConfiguration.of(nativeContext).dragDevices,
        isNot(contains(PointerDeviceKind.mouse)),
      );

      final webPages = <int>[];
      await tester.pumpWidget(
        wrap(db, isWeb: true, onPageChanged: webPages.add),
      );
      await tester.pumpAndSettle();

      final webContext = tester.element(find.byType(PageView));
      expect(
        ScrollConfiguration.of(webContext).dragDevices,
        contains(PointerDeviceKind.mouse),
      );
    },
  );

  testWidgets(
    'web: a mouse-wheel scroll turns exactly one page, even with a large '
    'delta -- not a continuous multi-page scroll',
    (tester) async {
      final db = await buildDb();
      addTearDown(db.close);
      await useSinglePageViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final webPages = <int>[];
      await tester.pumpWidget(
        wrap(db, isWeb: true, onPageChanged: webPages.add),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(MushafPager));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      // A single, large wheel delta -- large enough that PageView's own
      // default behavior would free-scroll through several pages' worth
      // of pixels, if left unhandled.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 2000)));
      await tester.pumpAndSettle();

      expect(webPages, [2]);
    },
  );
}
