import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/ui/full_bleed_content.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/khatmah/presentation/khatmah_section.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import '../../test_helpers/memory_storage.dart';

/// The khatmah counts a page read once on screen for 20 s (both pages of a
/// spread), keeps itself in storage, and Home shows today's share.
void main() {
  late MemoryStorage storage;
  var now = DateTime(2026, 11, 12, 9);

  setUp(() {
    storage = MemoryStorage();
    now = DateTime(2026, 11, 12, 9);
  });

  ProviderContainer container({bool spread = false}) {
    final c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(storage),
        memorizationClockProvider.overrideWithValue(() => now),
        if (spread) fullBleedContentProvider.overrideWithBuild((_, _) => true),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> show(ProviderContainer c, int page) async => c
      .read(mushafRecitationTargetProvider.notifier)
      .show(Object(), QuranLocation.page(1, page));

  testWidgets('a page on screen for 20 s is read; turned past, it is not', (
    tester,
  ) async {
    final c = container();
    await c.read(khatmahProvider.future);
    await c.read(khatmahProvider.notifier).start(30);
    await show(c, 1);
    await tester.pump(const Duration(seconds: 19));
    await show(c, 2); // turned on before 20 s
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    final k = c.read(khatmahProvider).value!;
    expect(k.readOn.keys, [2]);
    expect(k.readOn[2], '2026-11-12');
  });

  testWidgets('a two-page spread: both pages', (tester) async {
    final c = container(spread: true);
    await c.read(khatmahProvider.future);
    await c.read(khatmahProvider.notifier).start(30);
    await show(c, 4); // pages 3 and 4 shown
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(c.read(khatmahProvider).value!.readOn.keys.toSet(), {3, 4});
  });

  testWidgets('no khatmah: nothing is recorded', (tester) async {
    final c = container();
    await c.read(khatmahProvider.future);
    await show(c, 1);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(c.read(khatmahProvider).value, isNull);
    expect(storage.values, isEmpty);
  });

  testWidgets('kept in storage: read back, ended removed', (tester) async {
    var c = container();
    await c.read(khatmahProvider.future);
    await c.read(khatmahProvider.notifier).start(20);
    await c.read(khatmahProvider.notifier).readThrough(5);
    c = container();
    final back = await c.read(khatmahProvider.future);
    expect(back!.days, 20);
    expect(back.readOn.length, 5);
    await c.read(khatmahProvider.notifier).setDays(10);
    expect(c.read(khatmahProvider).value!.days, 10);
    await c.read(khatmahProvider.notifier).end();
    expect(c.read(khatmahProvider).value, isNull);
    expect(storage.values, isEmpty);
  });

  group('Home', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      final c = container();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: HomeKhatmahSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('started from Home: 30 days, today\'s pages', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('khatmah-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('khatmah-days-30')), findsOne);
      expect(find.text('About 21 pages a day'), findsOne);
      await tester.tap(find.byKey(const ValueKey('khatmah-days-15')));
      await tester.pumpAndSettle();
      expect(find.text('About 41 pages a day'), findsOne);
      await tester.tap(find.byKey(const ValueKey('khatmah-days-save')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahProvider).value!.days, 15);
      expect(find.text('Day 1 of 15'), findsOne);
      expect(find.text('Today: pages 1–41'), findsOne);
      expect(find.text('0 of 604 pages read'), findsOne);
      expect(find.byKey(const ValueKey('khatmah-read')), findsOne);
    });

    testWidgets('today\'s pages read: done, Read on', (tester) async {
      final c = await pump(tester);
      await c.read(khatmahProvider.notifier).start(30);
      await c.read(khatmahProvider.notifier).readThrough(10);
      await tester.pumpAndSettle();
      expect(find.text('10 of 21 read today'), findsOne);
      await c.read(khatmahProvider.notifier).readThrough(21);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('khatmah-today-done')), findsOne);
      expect(find.byKey(const ValueKey('khatmah-read-on')), findsOne);
    });

    testWidgets('the whole Quran read: complete, Start another', (
      tester,
    ) async {
      final c = await pump(tester);
      await c.read(khatmahProvider.notifier).start(30);
      await c.read(khatmahProvider.notifier).readThrough(604);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('khatmah-finished')), findsOne);
      expect(find.byKey(const ValueKey('khatmah-start-again')), findsOne);
    });

    testWidgets('its menu: read through a page, end it', (tester) async {
      final c = await pump(tester);
      await c.read(khatmahProvider.notifier).start(30);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-read-through')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('khatmah-read-through-page')),
        '700',
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-read-through-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne, reason: 'no page 700');
      await tester.enterText(
        find.byKey(const ValueKey('khatmah-read-through-page')),
        '30',
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-read-through-save')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahProvider).value!.readOn.length, 30);
      expect(find.text('30 of 604 pages read'), findsOne);

      await tester.tap(find.byKey(const ValueKey('khatmah-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-end-confirm')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahProvider).value, isNull);
      expect(find.byKey(const ValueKey('khatmah-start')), findsOne);
    });

    testWidgets('days typed: any number, its finish date', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('khatmah-start')));
      await tester.pumpAndSettle();
      expect(find.text('Finishes on Dec 11, 2026'), findsOne); // 30 days
      await tester.tap(find.byKey(const ValueKey('khatmah-days-other')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('khatmah-days-field')),
        '45',
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-days-field-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('khatmah-days-45')), findsOne);
      expect(find.text('About 14 pages a day'), findsOne);
      expect(find.text('Finishes on Dec 26, 2026'), findsOne);
      await tester.tap(find.byKey(const ValueKey('khatmah-days-save')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahProvider).value!.days, 45);
    });

    testWidgets('finish by a date: the days to it', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('khatmah-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-days-date')));
      await tester.pumpAndSettle();
      // The picker opens on the 30-day end (Dec 11): the 31st picked.
      await tester.tap(find.text('31'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Finishes on Dec 31, 2026'), findsOne);
      expect(find.byKey(const ValueKey('khatmah-days-50')), findsOne);
      await tester.tap(find.byKey(const ValueKey('khatmah-days-save')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahProvider).value!.days, 50);
    });

    testWidgets('a khatmah under way: its days changed, what is left shared', (
      tester,
    ) async {
      final c = await pump(tester);
      await c.read(khatmahProvider.notifier).start(30);
      await c.read(khatmahProvider.notifier).readThrough(300);
      await tester.pumpAndSettle();
      now = DateTime(2026, 11, 13, 9); // the next day
      await tester.tap(find.byKey(const ValueKey('khatmah-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-change-days')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-days-10')));
      await tester.pumpAndSettle();
      // 304 pages left over 9 days left.
      expect(find.text('About 34 pages a day'), findsOne);
      expect(find.text('Finishes on Nov 21, 2026'), findsOne);
    });
  });
}
