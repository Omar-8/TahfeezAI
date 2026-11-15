import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/khatmah/domain/khatmah.dart';
import 'package:tahfeez_ai/features/khatmah/domain/khatmah_history.dart';
import 'package:tahfeez_ai/features/memorize/presentation/progress_screen.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/progress_map.dart';

import '../../test_helpers/memory_storage.dart';
import '../../test_helpers/widget_test_overrides.dart';

/// The khatmahs completed: each kept once (a backup carries them), one
/// completed before they were kept counted too — and Progress shows how
/// many, the last one, and the one in progress.
void main() {
  late MemoryStorage storage;
  var now = DateTime(2026, 11, 14, 9);

  setUp(() {
    storage = MemoryStorage();
    now = DateTime(2026, 11, 14, 9);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(storage),
        memorizationClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a completed khatmah: its first and last day, the days it took', () {
    const k = Khatmah(start: '2026-10-01', days: 30);
    final done = CompletedKhatmah.of(
      k.readThrough(300, '2026-10-10').readThrough(604, '2026-10-28'),
    );
    expect((done.start, done.end, done.days), ('2026-10-01', '2026-10-28', 30));
    expect(done.tookDays, 28);
  });

  testWidgets('its last page read: kept once; a new one started keeps it', (
    tester,
  ) async {
    var c = container();
    await c.read(khatmahProvider.future);
    expect(await c.read(khatmahHistoryProvider.future), isEmpty);
    final k = c.read(khatmahProvider.notifier);
    await k.start(30);
    await k.readThrough(604);
    await k.readThrough(604); // nothing new
    expect(c.read(khatmahHistoryProvider).value, hasLength(1));
    await k.start(15);
    // Read back from storage.
    c = container();
    final done = await c.read(khatmahHistoryProvider.future);
    expect(done, hasLength(1));
    expect(done.single.start, '2026-11-14');
    expect(done.single.end, '2026-11-14');
    // (The celebration's own time run out.)
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('one completed before they were kept (still the current one): '
      'counted, and kept', (tester) async {
    var c = container();
    await c.read(khatmahProvider.future);
    // As an earlier version left it: the khatmah, its every page read.
    await c.read(khatmahProvider.notifier).start(30);
    await c.read(khatmahProvider.notifier).readThrough(604);
    await storage.remove('khatmah.completed.v1');
    c = container();
    expect(await c.read(khatmahHistoryProvider.future), hasLength(1));
    await c.read(khatmahProvider.notifier).start(10);
    c = container();
    expect(await c.read(khatmahHistoryProvider.future), hasLength(1));
    await tester.pump(const Duration(seconds: 10));
  });

  group('Progress', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      double width = 420,
      double textScale = 1,
      String locale = 'en',
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(
        overrides: [
          ...tahfeezWidgetTestOverrides(),
          browserStorageProvider.overrideWithValue(storage),
          memorizationClockProvider.overrideWithValue(() => now),
          progressMapProvider.overrideWith(
            (ref) async => ProgressMapBuilder.build(
              memories: const {},
              pages: const {},
              juzOfAyah: const {},
              now: now,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const Scaffold(body: MemorizationProgressView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('none yet: 0, and Start a khatmah', (tester) async {
      await pump(tester);
      final card = find.byKey(const ValueKey('progress-khatmah'));
      await tester.scrollUntilVisible(card, 200);
      expect(find.text('No khatmah completed yet'), findsOne);
      expect(find.byKey(const ValueKey('progress-khatmah-start')), findsOne);
      expect(find.byKey(const ValueKey('progress-khatmah-bar')), findsNothing);
    });

    testWidgets('two completed, a third under way: 2, the last, its bar', (
      tester,
    ) async {
      final c = await pump(tester);
      final k = c.read(khatmahProvider.notifier);
      await c.read(khatmahHistoryProvider.future);
      now = DateTime(2026, 9, 1, 9);
      await k.start(30);
      await k.readThrough(604);
      now = DateTime(2026, 10, 1, 9);
      await k.start(30);
      now = DateTime(2026, 10, 20, 9);
      await k.readThrough(604);
      now = DateTime(2026, 11, 14, 9);
      await k.start(30);
      await k.readThrough(151);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('progress-khatmah')),
        200,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('progress-khatmah-count')))
            .data,
        '2',
      );
      expect(find.text('khatmahs completed'), findsOne);
      expect(find.text('Last completed Oct 20, 2026, in 20 days'), findsOne);
      expect(find.text('151 of 604 pages read'), findsOne);
      expect(find.text('Day 1 of 30'), findsOne);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('progress-khatmah-bar')),
            )
            .value,
        closeTo(151 / 604, 1e-9),
      );

      // Tapped: each completed, the latest first (owner, 2026-11-15).
      await tester.tap(find.byKey(const ValueKey('progress-khatmah-count')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('khatmah-history')), findsOne);
      final second = find.byKey(const ValueKey('khatmah-history-2'));
      final first = find.byKey(const ValueKey('khatmah-history-1'));
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
        reason: 'the latest first',
      );
      expect(
        find.descendant(
          of: second,
          matching: find.text('Oct 1, 2026 – Oct 20, 2026'),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: second,
          matching: find.text('20 days · planned for 30 days'),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: first,
          matching: find.text('Sep 1, 2026 – Sep 1, 2026'),
        ),
        findsOne,
      );
    });

    for (final locale in ['en', 'de', 'ru', 'ar', 'ur', 'ja']) {
      testWidgets('$locale: the card at 320 px, text twice its size', (
        tester,
      ) async {
        final c = await pump(tester, width: 320, textScale: 2, locale: locale);
        final k = c.read(khatmahProvider.notifier);
        await c.read(khatmahHistoryProvider.future);
        now = DateTime(2026, 9, 1, 9);
        await k.start(60);
        await k.readThrough(604);
        now = DateTime(2026, 11, 14, 9);
        await k.start(30);
        await k.readThrough(50);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('progress-khatmah')),
          200,
        );
        expect(tester.takeException(), isNull);
        // Its list too.
        await tester.tap(find.byKey(const ValueKey('progress-khatmah-count')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('khatmah-history-1')), findsOne);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
