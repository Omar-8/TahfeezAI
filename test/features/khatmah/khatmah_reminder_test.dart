import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_reminder.dart';
import 'package:tahfeez_ai/features/khatmah/domain/khatmah.dart';
import 'package:tahfeez_ai/features/khatmah/presentation/khatmah_section.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/fake_reminder_scheduler.dart';
import '../../test_helpers/memory_storage.dart';

/// The khatmah reminder: each day's pages at its time, scheduled again as
/// the khatmah changes — today's left out once read, none after the end.
void main() {
  group('the plan', () {
    final now = DateTime(2026, 11, 12, 9);
    const k = Khatmah(start: '2026-11-12', days: 30);

    test('today\'s time passed: from tomorrow, 14 days', () {
      final plan = khatmahReminderPlan(k, now, 7 * 60);
      expect(plan, hasLength(14));
      expect(plan.first.$1, DateTime(2026, 11, 13, 7));
      expect(plan.first.$2.dayNo, 2);
      // Nothing read: 604 pages over the 29 days left.
      expect((plan.first.$2.from, plan.first.$2.to), (1, 21));
      expect(plan.last.$1, DateTime(2026, 11, 26, 7));
    });

    test('today\'s time to come: today first; read, left out', () {
      var plan = khatmahReminderPlan(k, now, 20 * 60);
      expect(plan.first.$1, DateTime(2026, 11, 12, 20));
      expect((plan.first.$2.from, plan.first.$2.to), (1, 21));
      final read = k.readThrough(21, '2026-11-12');
      plan = khatmahReminderPlan(read, now, 20 * 60);
      expect(plan.first.$1, DateTime(2026, 11, 13, 20));
      expect((plan.first.$2.from, plan.first.$2.to), (22, 42));
    });

    test('the Quran read: none', () {
      expect(
        khatmahReminderPlan(k.readThrough(604, '2026-11-12'), now, 20 * 60),
        isEmpty,
      );
    });

    test('past its days: still each day, what is left', () {
      const late = Khatmah(start: '2026-10-01', days: 10);
      final plan = khatmahReminderPlan(late, now, 7 * 60);
      expect(plan, hasLength(14));
      expect(plan.first.$2.dayNo, greaterThan(10));
      expect((plan.first.$2.from, plan.first.$2.to), (1, 604));
    });
  });

  group('the controller', () {
    late MemoryStorage storage;
    late FakeReminderScheduler scheduler;
    final now = DateTime(2026, 11, 12, 9);

    setUp(() {
      storage = MemoryStorage();
      scheduler = FakeReminderScheduler();
    });

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          browserStorageProvider.overrideWithValue(storage),
          memorizationClockProvider.overrideWithValue(() => now),
          dailyReminderSchedulerProvider.overrideWithValue(scheduler),
          localeControllerProvider.overrideWithBuild((ref, _) => null),
        ],
      );
      addTearDown(c.dispose);
      c.listen(khatmahReminderProvider, (_, _) {});
      return c;
    }

    test('off by default; on: each day\'s pages, again as they are read; '
        'ended: none', () async {
      final c = container();
      await pumpEventQueue();
      expect(c.read(khatmahReminderProvider).enabled, isFalse);
      expect(scheduler.handlers, contains(KhatmahReminderController.payload));
      final reminder = c.read(khatmahReminderProvider.notifier);
      final khatmah = c.read(khatmahProvider.notifier);

      expect(await reminder.setEnabled(true), isTrue);
      expect(scheduler.once, isEmpty); // no khatmah yet
      await khatmah.start(30);
      await pumpEventQueue();
      expect(scheduler.once, hasLength(14));
      // 7:00 already passed today.
      expect(scheduler.once[100]!.at, DateTime(2026, 11, 13, 7));
      expect(scheduler.once[100]!.title, 'Khatmah · Day 2 of 30');
      expect(scheduler.once[100]!.body, 'Today: pages 1–21');

      await reminder.setTime(20 * 60);
      expect(scheduler.once[100]!.at, DateTime(2026, 11, 12, 20));
      expect(scheduler.once[100]!.title, 'Khatmah · Day 1 of 30');

      await khatmah.readThrough(21);
      await pumpEventQueue();
      expect(scheduler.once[100]!.at, DateTime(2026, 11, 13, 20));
      expect(scheduler.once[100]!.body, 'Today: pages 22–42');

      await khatmah.end();
      await pumpEventQueue();
      expect(scheduler.once, isEmpty);
    });

    test('kept: on and its time come back at the next start', () async {
      var c = container();
      await pumpEventQueue();
      await c.read(khatmahProvider.notifier).start(30);
      await c.read(khatmahReminderProvider.notifier).setTime(21 * 60);
      await c.read(khatmahReminderProvider.notifier).setEnabled(true);
      scheduler.once.clear();
      c = container();
      await pumpEventQueue();
      expect(c.read(khatmahReminderProvider), (enabled: true, minutes: 1260));
      expect(scheduler.once[100]!.at, DateTime(2026, 11, 12, 21));
    });

    test('off: none; without permission it stays off', () async {
      final c = container();
      await pumpEventQueue();
      await c.read(khatmahProvider.notifier).start(30);
      final reminder = c.read(khatmahReminderProvider.notifier);
      await reminder.setEnabled(true);
      await reminder.setEnabled(false);
      expect(scheduler.once, isEmpty);

      scheduler = FakeReminderScheduler(granted: false);
      final denied = container();
      await pumpEventQueue();
      expect(
        await denied.read(khatmahReminderProvider.notifier).setEnabled(true),
        isFalse,
      );
      expect(denied.read(khatmahReminderProvider).enabled, isFalse);
    });
  });

  group('Home', () {
    late FakeReminderScheduler scheduler;

    Future<ProviderContainer> pump(WidgetTester tester) async {
      scheduler = FakeReminderScheduler();
      final c = ProviderContainer(
        overrides: [
          browserStorageProvider.overrideWithValue(MemoryStorage()),
          memorizationClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 12, 9),
          ),
          dailyReminderSchedulerProvider.overrideWithValue(scheduler),
          localeControllerProvider.overrideWithBuild((ref, _) => null),
        ],
      );
      addTearDown(c.dispose);
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

    testWidgets('started with "Remind me": on, its days scheduled', (
      tester,
    ) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('khatmah-start')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('khatmah-days-remind')),
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-days-remind')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('khatmah-days-save')),
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-days-save')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahReminderProvider).enabled, isTrue);
      expect(scheduler.once, hasLength(14));
    });

    testWidgets('its menu: the reminder sheet turns it on and off', (
      tester,
    ) async {
      final c = await pump(tester);
      await c.read(khatmahProvider.notifier).start(30);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-reminder')));
      await tester.pumpAndSettle();
      expect(find.text('Every day at 7:00 AM'), findsOne);
      await tester.tap(find.byKey(const ValueKey('khatmah-reminder-switch')));
      await tester.pumpAndSettle();
      expect(c.read(khatmahReminderProvider).enabled, isTrue);
      expect(scheduler.once, hasLength(14));
      await tester.tap(find.byKey(const ValueKey('khatmah-reminder-switch')));
      await tester.pumpAndSettle();
      expect(scheduler.once, isEmpty);
    });
  });
}
