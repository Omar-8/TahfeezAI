import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/khatmah/domain/khatmah.dart';

/// A khatmah's days: the pages left shared over the days left, a missed day
/// spread over the rest, reading ahead making the next days lighter.
void main() {
  const start = '2026-11-01';
  const k = Khatmah(start: start, days: 30);

  String day(int n) => khatmahDay(DateTime(2026, 11, n));

  test('day one: about a juz, from page 1', () {
    final t = k.today(start);
    expect(t.dayNo, 1);
    expect(t.days, 30);
    expect((t.from, t.to, t.pages), (1, 21, 21)); // 604 / 30 → 21
    expect(t.nextPage, 1);
    expect(t.doneToday, isFalse);
    expect(t.read, 0);
  });

  test('pages read today count towards today; done once all are', () {
    var r = k.reading([for (var p = 1; p <= 10; p++) p], start);
    var t = r.today(start);
    expect((t.from, t.to), (1, 21), reason: 'today\'s portion stays');
    expect(t.readToday, 10);
    expect(t.nextPage, 11);
    r = r.reading([for (var p = 11; p <= 21; p++) p], start);
    t = r.today(start);
    expect(t.doneToday, isTrue);
    expect(t.nextPage, isNull);
    expect(t.read, 21);
  });

  test('the next day starts where the reading stopped', () {
    final r = k.readThrough(21, start);
    final t = r.today(day(2));
    expect(t.dayNo, 2);
    expect(t.from, 22);
    expect(t.pages, ((604 - 21) / 29).ceil());
  });

  test('a missed day spreads over the days left', () {
    final r = k.readThrough(10, start);
    final onTime = r.today(day(2)), late = r.today(day(4));
    expect(late.from, 11);
    expect(late.pages, ((604 - 10) / 27).ceil());
    expect(late.pages, greaterThan(onTime.pages));
    expect(late.pages, lessThan(onTime.pages * 2), reason: 'not piled up');
  });

  test('reading ahead makes the next days lighter', () {
    final r = k.readThrough(60, start);
    final t = r.today(day(2));
    expect(t.from, 61);
    expect(t.pages, ((604 - 60) / 29).ceil());
    expect(t.pages, lessThan(21));
  });

  test('past the last day: everything left, today', () {
    final r = k.readThrough(500, start);
    expect(r.today(day(30)).dayNo, 30);
    final t = r.today('2026-12-05');
    expect(t.dayNo, greaterThan(30));
    expect((t.from, t.to, t.pages), (501, 604, 104));
  });

  test('pages read out of order: the first unread first', () {
    final r = k.reading([1, 2, 3, 10], start);
    final t = r.today(day(2));
    expect(t.from, 4);
    expect(t.nextPage, 4);
  });

  test('every page read: finished', () {
    final r = k.readThrough(604, start);
    final t = r.today(day(5));
    expect(t.finished, isTrue);
    expect(t.progress, 1);
  });

  test('a page read again keeps its first day; outside pages ignored', () {
    final r = k.reading([5], start).reading([5, 0, 605], day(2));
    expect(r.readOn, {5: start});
    expect(identical(r.reading([5], day(3)), r), isTrue);
  });

  test('its days changed: the share follows', () {
    final r = k.readThrough(21, start).copyWith(days: 10);
    expect(r.today(day(2)).pages, ((604 - 21) / 9).ceil());
  });

  test('kept as JSON and read back; anything else read as none', () {
    final r = k.readThrough(3, start).reading([9], day(2));
    final back = Khatmah.fromJson(r.toJson())!;
    expect(back.start, start);
    expect(back.days, 30);
    expect(back.readOn, r.readOn);
    expect(Khatmah.fromJson(null), isNull);
    expect(Khatmah.fromJson({'start': 'x', 'days': 3}), isNull);
    expect(Khatmah.fromJson({'start': start, 'days': 0}), isNull);
  });

  test('a day is the local date', () {
    expect(khatmahDay(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
  });
}
