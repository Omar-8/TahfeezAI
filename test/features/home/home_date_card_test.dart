import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/clock_format.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/habits/domain/hijri.dart';
import 'package:tahfeez_ai/features/home/presentation/home_date_card.dart';
import 'package:tahfeez_ai/features/home/presentation/hijri_calendar_screen.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/real_app.dart';

/// Home's date (owner, 2026-11-21): today, the time, the Hijri date, a
/// sky by the time of day; a Hijri event from two days before it.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  /// The day [event] falls on in Hijri year [year].
  DateTime dayOf(HijriEvent event, int year) {
    var d = DateTime(2026, 1, 1);
    while (true) {
      final h = hijriOf(d);
      if (h.year == year && h.month == event.month && h.day == event.day) {
        return d;
      }
      d = DateTime(d.year, d.month, d.day + 1);
    }
  }

  test('the sky: sunrise, the day, sunset, the night', () {
    expect(SkyTime.of(DateTime(2026, 1, 1, 5, 30)), SkyTime.sunrise);
    expect(SkyTime.of(DateTime(2026, 1, 1, 12)), SkyTime.day);
    expect(SkyTime.of(DateTime(2026, 1, 1, 18)), SkyTime.sunset);
    expect(SkyTime.of(DateTime(2026, 1, 1, 23)), SkyTime.night);
    expect(SkyTime.of(DateTime(2026, 1, 1, 2)), SkyTime.night);
  });

  test("events from two days before: ʿArafah in 2 days, tomorrow, today; "
      'Eid al-Adha the day after', () {
    final arafah = dayOf(HijriEvent.arafah, 1448);
    DateTime before(int n) =>
        DateTime(arafah.year, arafah.month, arafah.day - n);
    expect(nextHijriEvent(before(3))?.event, isNot(HijriEvent.arafah));
    expect(nextHijriEvent(before(2)), (event: HijriEvent.arafah, inDays: 2));
    expect(nextHijriEvent(before(1)), (event: HijriEvent.arafah, inDays: 1));
    expect(nextHijriEvent(arafah), (event: HijriEvent.arafah, inDays: 0));
    expect(
      nextHijriEvent(DateTime(arafah.year, arafah.month, arafah.day + 1)),
      (event: HijriEvent.eidAdha, inDays: 0),
    );
    // Where the month begins a day later: ʿArafah a day further off.
    expect(nextHijriEvent(before(2), adjust: -1), isNull);
    expect(nextHijriEvent(before(1), adjust: -1), (
      event: HijriEvent.arafah,
      inDays: 2,
    ));
  });

  test('a Hijri month: from its 1st, 29 or 30 days, each with its '
      'Gregorian date; moved a day where asked', () {
    final ramadan = hijriMonthDays(1448, 9);
    expect(ramadan.first.day, 1);
    expect(ramadan.length, inInclusiveRange(29, 30));
    expect(hijriOf(ramadan.first.date), (year: 1448, month: 9, day: 1));
    expect(
      ramadan.last.date.difference(ramadan.first.date).inDays,
      ramadan.length - 1,
    );
    final later = hijriMonthDays(1448, 9, adjust: -1);
    expect(
      later.first.date,
      DateTime(
        ramadan.first.date.year,
        ramadan.first.date.month,
        ramadan.first.date.day + 1,
      ),
    );
  });

  testWidgets("Home's date tapped: the Hijri calendar — this month, today "
      'in it, its events; the months before and after', (tester) async {
    final arafah = dayOf(HijriEvent.arafah, 1448);
    await RealApp.launch(
      tester,
      route: '/home',
      overrides: [
        memorizationClockProvider.overrideWithValue(
          () => DateTime(arafah.year, arafah.month, arafah.day - 4, 10),
        ),
      ],
    );
    await RealApp.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-date')));
    await RealApp.settle(tester);
    expect(find.text('Dhu al-Hijjah 1448'), findsOneWidget);
    expect(find.byKey(const ValueKey('hijri-day-5')), findsOneWidget);
    final list = find
        .ancestor(
          of: find.byKey(const ValueKey('hijri-month')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final e in ['dhulHijjahTen', 'arafah', 'eidAdha']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('hijri-event-$e')),
        100,
        scrollable: list,
      );
      expect(find.byKey(ValueKey('hijri-event-$e')), findsOneWidget, reason: e);
    }
    await tester.drag(list, const Offset(0, 1000));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('hijri-this-month')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hijri-next')));
    await RealApp.settle(tester);
    expect(find.text('Muharram 1449'), findsOneWidget);
    for (final e in ['newYear', 'ashura']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('hijri-event-$e')),
        100,
        scrollable: list,
      );
    }
    await tester.drag(list, const Offset(0, 1000));
    await RealApp.settle(tester);
    await tester.tap(find.byKey(const ValueKey('hijri-this-month')));
    await RealApp.settle(tester);
    expect(find.text('Dhu al-Hijjah 1448'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hijri-previous')));
    await RealApp.settle(tester);
    expect(find.text('Dhu al-Qaʿdah 1448'), findsOneWidget);
    await RealApp.quit(tester);
  });

  testWidgets('on Home: the date, the time, the Hijri date, the event', (
    tester,
  ) async {
    final eid = dayOf(HijriEvent.eidFitr, 1448);
    final at = DateTime(eid.year, eid.month, eid.day - 1, 21, 5);
    await RealApp.launch(
      tester,
      route: '/home',
      overrides: [memorizationClockProvider.overrideWithValue(() => at)],
    );
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('home-date')), findsOneWidget);
    // (The card's own: Home's sky follows the real clock.)
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-date')),
        matching: find.byKey(const ValueKey('home-sky-night')),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('9:05'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-date-hijri'))).data,
      endsWith('Ramadan 1448 AH'),
    );
    expect(find.text('Eid al-Fitr: tomorrow'), findsOneWidget);
    // The time on a glass square, in the app's green (owner, 2026-11-22:
    // the time there, not the day): hours and minutes, AM/PM under them.
    final tile = find.byKey(const ValueKey('home-date-time'));
    expect(tester.widget(tile), isA<TahfeezGlassSurface>());
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        )
        .toList();
    expect([for (final t in texts) t.data], ['9:05', 'PM']);
    expect(
      texts.first.style?.color,
      Theme.of(tester.element(tile)).colorScheme.primary,
    );
    // 24-hour chosen in Settings (owner, 2026-11-22): 21:05, no AM/PM.
    final container = ProviderScope.containerOf(tester.element(tile));
    await container.read(clockFormatProvider.notifier).set(ClockFormat.h24);
    await tester.pumpAndSettle();
    expect(
      [
        for (final t in tester.widgetList<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        ))
          t.data,
      ],
      ['21:05'],
    );
    await container.read(clockFormatProvider.notifier).set(ClockFormat.system);
    await tester.pumpAndSettle();
    // Today's date first, the Hijri date under it.
    expect(
      tester.getRect(find.byKey(const ValueKey('home-date-today'))).top,
      lessThan(
        tester.getRect(find.byKey(const ValueKey('home-date-hijri'))).top,
      ),
    );
    // Above the shortcuts.
    expect(
      tester.getRect(find.byKey(const ValueKey('home-date'))).bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey('home-qibla'))).top),
    );
    await RealApp.quit(tester);
  });
}
