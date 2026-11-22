import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_haptics.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_progress.dart';
import 'package:tahfeez_ai/features/athkar/data/athkar_source.dart';
import 'package:tahfeez_ai/features/habits/application/habits_controller.dart';
import 'package:tahfeez_ai/features/habits/domain/habit_catalog.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/real_app.dart';

/// Habits (owner, 2026-11-21): from Home and the side menu; added from the
/// catalog or one's own; ticked today or a day forgotten, with how much;
/// a wird counted; how they go.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final now = DateTime(2026, 11, 21, 10);
  late List<bool> felt;

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/home',
  }) {
    felt = [];
    return RealApp.launch(
      tester,
      route: route,
      overrides: [
        memorizationClockProvider.overrideWithValue(() => now),
        athkarHapticsProvider.overrideWithValue(
          ({required bool done}) => felt.add(done),
        ),
      ],
    );
  }

  /// No habits left (kept on the phone between tests).
  Future<void> clear(WidgetTester tester, ProviderContainer c) async {
    for (final h in [...c.read(habitsProvider).habits]) {
      c.read(habitsProvider.notifier).remove(h.id);
    }
    await RealApp.settle(tester);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets("Home's Habits: none yet — one added from the catalog, its "
      'own page; today\'s list: ticked, its amount, a day forgotten', (
    tester,
  ) async {
    final c = await launch(tester);
    await RealApp.settle(tester);
    await tester.tap(key('home-habits'));
    await RealApp.settle(tester);
    expect(key('habits-empty'), findsOneWidget);
    await tester.tap(key('habits-empty-add'));
    await RealApp.settle(tester);
    // A tap opens it — not added yet (owner, 2026-11-21): its rakʿahs
    // two by two, its days and reminders to choose, then "Add habit".
    await tester.tap(key('habit-template-duha'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).habits, isEmpty);
    for (final p in [2, 4, 6, 8]) {
      expect(key('habit-preset-$p'), findsOneWidget, reason: '$p');
    }
    expect(key('habit-preset-3'), findsNothing);
    await tester.tap(key('habit-preset-4'));
    await RealApp.settle(tester);
    await tester.tap(key('habit-template-add'));
    await RealApp.settle(tester);
    final duha = c.read(habitsProvider).habits.single;
    expect((duha.template, duha.target), ('duha', 4));
    expect(find.text('Ḍuḥā prayer'), findsOneWidget);
    expect(key('habit-detail'), findsOneWidget);
    // Back: past its page to the catalog — added there now (a tick).
    await tester.pageBack();
    await RealApp.settle(tester);
    await tester.pageBack();
    await RealApp.settle(tester);

    // Two tabs (as Memorize's), "Add a habit" as a glass pill and after
    // the list.
    expect(key('habits-tab-today'), findsOneWidget);
    expect(key('habits-tab-progress'), findsOneWidget);
    expect(key('habits-add'), findsOneWidget);
    expect(key('habits-add-more'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
    // The ring's middle: the numbers, then a tick once all are done.
    expect(tester.widget<Text>(key('habits-ring-count')).data, '0/1');
    await tester.tap(key('habit-check-${duha.id}'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn(duha.id, '2026-11-21'), 4);
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(key('habits-ring-done'), findsOneWidget);

    // Its amount: a long press asks.
    await tester.tap(key('habit-check-${duha.id}'));
    await RealApp.settle(tester);
    await tester.longPress(key('habit-check-${duha.id}'));
    await RealApp.settle(tester);
    await tester.enterText(key('habit-amount-field'), '6');
    await tester.tap(key('habit-amount-ok'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn(duha.id, '2026-11-21'), 6);
    expect(find.text('6 rakʿahs'), findsOneWidget);

    // Yesterday — not due (added today): nothing then.
    await tester.tap(key('habits-day-2026-11-20'));
    await RealApp.settle(tester);
    expect(find.text('Nothing due this day.'), findsOneWidget);
    await clear(tester, c);
    await RealApp.quit(tester);
  });

  testWidgets('its calendar: a day forgotten ticked (the last amount); its '
      'target changed; removed', (tester) async {
    // Added on the 1st, ticked once (3 rakʿahs) — as the phone kept it.
    final setup = await launch(tester);
    await RealApp.settle(tester);
    await tester.runAsync(
      () => setup
          .read(browserStorageProvider)
          .setString(
            HabitsController.storageKey,
            jsonEncode({
              'habits': [
                {
                  'id': 'h1',
                  'template': 'witr',
                  'schedule': {'kind': 'daily'},
                  'target': 3,
                  'unit': 'rakahs',
                  'reminders': <Object>[],
                  'since': '2026-11-01',
                },
              ],
              'log': {
                'h1': {'2026-11-05': 5},
              },
              'hijriAdjust': 0,
            }),
          ),
    );
    await RealApp.quit(tester);
    final c = await launch(tester, route: '/habits/h1');
    await RealApp.settle(tester);
    expect(find.text('Witr'), findsOneWidget);
    expect(find.textContaining('1 of 21 days'), findsOneWidget);
    // The 12th, forgotten: ticked with the last amount (5).
    await tester.tap(key('habit-day-2026-11-12'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn('h1', '2026-11-12'), 5);
    expect(find.textContaining('2 of 21 days'), findsOneWidget);
    // Before it was added, or still to come: not tappable.
    await tester.tap(key('habit-day-2026-11-25'), warnIfMissed: false);
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn('h1', '2026-11-25'), isNull);
    // Tapped again: not done.
    await tester.tap(key('habit-day-2026-11-12'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn('h1', '2026-11-12'), isNull);

    await tester.scrollUntilVisible(
      key('habit-remove'),
      200,
      scrollable: find
          .descendant(
            of: key('habit-detail'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Witr: odd, 1 to 9 ready, any other on the stepper.
    for (final p in [1, 3, 5, 7, 9]) {
      expect(key('habit-preset-$p'), findsOneWidget, reason: '$p');
    }
    await tester.tap(key('habit-preset-7'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).habit('h1')!.target, 7);
    // Its progress, as Memorize's: all it gave, its streaks, the month.
    expect(key('habit-stats'), findsOneWidget);
    expect(find.text('Rakʿahs prayed'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    await tester.tap(key('habit-remove'));
    await RealApp.settle(tester);
    await tester.tap(key('habit-remove-confirm'));
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).habits, isEmpty);
    expect(c.read(habitsProvider).log['h1'], isNull);
    await RealApp.quit(tester);
  });

  testWidgets('a wird counted: a tap each, felt; done at its target', (
    tester,
  ) async {
    final c = await launch(tester, route: '/habits/add');
    await RealApp.settle(tester);
    await tester.scrollUntilVisible(
      key('habit-template-wirdSubhanAzim'),
      200,
      scrollable: find.descendant(
        of: key('habits-catalog'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(key('habit-template-wirdSubhanAzim'));
    await RealApp.settle(tester);
    await tester.tap(key('habit-template-add'));
    await RealApp.settle(tester);
    final wird = c.read(habitsProvider).habits.single;
    c.read(habitsProvider.notifier).update(wird.copyWith(target: () => 3));
    await RealApp.settle(tester);
    await tester.tap(key('habit-count'));
    await RealApp.settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(key('habit-counter'));
      await tester.pump();
    }
    expect(felt, [false, false, true]);
    expect(c.read(habitsProvider).amountOn(wird.id, '2026-11-21'), 3);
    // No further.
    await tester.tap(key('habit-counter'));
    await tester.pump();
    expect(c.read(habitsProvider).amountOn(wird.id, '2026-11-21'), 3);
    await clear(tester, c);
    await RealApp.quit(tester);
  });

  testWidgets("one's own habit: named, its days and what it counts", (
    tester,
  ) async {
    final c = await launch(tester, route: '/habits/new');
    await RealApp.settle(tester);
    await tester.enterText(key('habit-new-name'), 'Walk');
    await tester.pump();
    await tester.tap(key('habit-new-weekday-6'));
    await tester.tap(key('habit-new-weekday-7'));
    await tester.tap(key('habit-new-unit-minutes'));
    await RealApp.settle(tester);
    await tester.tap(key('habit-new-save'));
    await RealApp.settle(tester);
    final walk = c.read(habitsProvider).habits.single;
    expect(walk.name, 'Walk');
    expect(walk.template, isNull);
    expect(find.text('Walk'), findsOneWidget, reason: 'its own page');
    expect(
      c.read(habitsProvider).dueOn(walk, DateTime(2026, 11, 21)),
      isFalse,
      reason: 'Saturday left out',
    );
    expect(c.read(habitsProvider).dueOn(walk, DateTime(2026, 11, 23)), isTrue);
    await clear(tester, c);
    await RealApp.quit(tester);
  });

  testWidgets('in step with the app (owner, 2026-11-21): the khatmah\'s '
      'pages read count as the day\'s Quran reading; Athkar\'s Morning & '
      'Evening finished ticks the morning athkar', (tester) async {
    final c = await launch(tester, route: '/habits');
    await RealApp.settle(tester);
    final h = c.read(habitsProvider.notifier);
    final reading = h.addTemplate(habitTemplate('quranPages')!);
    final morning = h.addTemplate(habitTemplate('athkarMorning')!);
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn(reading.id, '2026-11-21'), isNull);

    // Three pages read in the khatmah today.
    await tester.runAsync(() async {
      final k = c.read(khatmahProvider.notifier);
      await k.start(30);
      await k.read([1, 2, 3]);
    });
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn(reading.id, '2026-11-21'), 3);

    // Morning & Evening finished at 10:00 in Athkar: the morning ticked.
    final book = await tester.runAsync(() => c.read(athkarBookProvider.future));
    final progress = c.read(athkarProgressProvider.notifier);
    for (final z in book!.category(27)!.athkar) {
      for (var i = 0; i < z.repeat; i++) {
        progress.count(z);
      }
    }
    await RealApp.settle(tester);
    expect(c.read(habitsProvider).amountOn(morning.id, '2026-11-21'), 1);
    progress.reset(book.category(27)!);
    await clear(tester, c);
    await tester.runAsync(() => c.read(khatmahProvider.notifier).end());
    await RealApp.quit(tester);
  });

  testWidgets('from the side menu', (tester) async {
    await launch(tester);
    await RealApp.settle(tester);
    await openFromMenu(tester, 'habits');
    expect(key('habits-empty'), findsOneWidget);
    await RealApp.quit(tester);
  });
}
