import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/activity_calendar.dart';

void main() {
  final today = DateTime(2026, 10, 25, 21, 30);
  DateTime day(int d) => DateTime(2026, 10, d);

  test('the streak runs up to today, or yesterday before today has any', () {
    final c = ActivityCalendar({
      day(25): 4,
      day(24): 1,
      day(23): 9,
      day(21): 2,
    }, today: today);
    expect(c.current, 3);
    final notYet = ActivityCalendar({day(24): 1, day(23): 9}, today: today);
    expect(notYet.current, 2);
    final broken = ActivityCalendar({day(23): 9}, today: today);
    expect(broken.current, 0);
  });

  test('the longest run ever, across a month and a clock change', () {
    final c = ActivityCalendar({
      DateTime(2026, 3, 28): 1,
      DateTime(2026, 3, 29): 1, // Europe's clocks go forward
      DateTime(2026, 3, 30): 1,
      DateTime(2026, 3, 31): 1,
      DateTime(2026, 4, 1): 1,
      day(25): 1,
    }, today: today);
    expect(c.longest, 5);
    expect(c.current, 1);
  });

  test('days with nothing recited are left out', () {
    final c = ActivityCalendar({day(25): 0}, today: today);
    expect(c.days, isEmpty);
    expect(c.current, 0);
    expect(c.longest, 0);
  });
}
