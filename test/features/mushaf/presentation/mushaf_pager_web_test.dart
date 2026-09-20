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
  }) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        platformCapabilitiesProvider.overrideWithValue(
          _FakePlatformCapabilities(isWeb: isWeb),
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
        (w) => w is SizedBox && w.width == 24,
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
        (w) => w is SizedBox && w.width == 24,
      );
      // Both pages of the spread (page 1 and page 2) are bordered.
      expect(borderedWeb, findsNWidgets(2));
      expect(gapWeb, findsOneWidget);
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
