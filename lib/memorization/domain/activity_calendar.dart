/// The days ayahs were recited on (local dates, how many each day), for
/// the streak and the calendar on the Progress screen.
class ActivityCalendar {
  ActivityCalendar(Map<DateTime, int> days, {required DateTime today})
    : today = dateOf(today),
      days = {
        for (final MapEntry(key: day, value: n) in days.entries)
          if (n > 0) dateOf(day): n,
      };

  /// Ayahs recited, by local date (days without any left out).
  final Map<DateTime, int> days;
  final DateTime today;

  static DateTime dateOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [day] moved by [n] days (by the calendar: daylight saving changes
  /// don't shift it).
  static DateTime shift(DateTime day, int n) =>
      DateTime(day.year, day.month, day.day + n);

  int on(DateTime day) => days[dateOf(day)] ?? 0;

  /// Days in a row with recitation, up to today — or up to yesterday while
  /// today has none yet (the streak is not broken before the day ends).
  int get current {
    var day = on(today) > 0 ? today : shift(today, -1);
    var n = 0;
    while (on(day) > 0) {
      n++;
      day = shift(day, -1);
    }
    return n;
  }

  /// The most days in a row ever.
  int get longest {
    final sorted = days.keys.toList()..sort();
    var best = 0, run = 0;
    DateTime? last;
    for (final day in sorted) {
      run = last != null && shift(last, 1) == day ? run + 1 : 1;
      if (run > best) best = run;
      last = day;
    }
    return best;
  }
}
