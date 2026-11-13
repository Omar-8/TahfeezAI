/// A khatmah: reading the whole Quran, page by page, in a chosen number of
/// days. Each day's portion is what is left shared over the days left, so
/// a missed day spreads over the rest instead of piling up; reading ahead
/// makes the next days lighter.
library;

/// The Madinah Mushaf's pages.
const kKhatmahPages = 604;

/// A day as the khatmah counts it: the local date, `yyyy-mm-dd`.
String khatmahDay(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

DateTime _date(String day) => DateTime.parse(day);

/// Today's share of a khatmah.
class KhatmahToday {
  const KhatmahToday({
    required this.dayNo,
    required this.days,
    required this.from,
    required this.to,
    required this.pages,
    required this.readToday,
    required this.nextPage,
    required this.read,
    required this.total,
  });

  /// Which day of the khatmah today is (1 on the day it began), of [days]
  /// — past the last day, still counting.
  final int dayNo, days;

  /// Today's portion: pages [from]–[to] (the unread ones in it, [pages]).
  final int from, to, pages;

  /// Pages of today's portion read today.
  final int readToday;

  /// The first page of today's portion not read yet (where to open);
  /// `null` when today's portion is read.
  final int? nextPage;

  /// Pages read in all, of [total].
  final int read, total;

  bool get doneToday => nextPage == null;
  bool get finished => read >= total;
  double get progress => total == 0 ? 0 : read / total;
}

/// A khatmah in progress: begun on [start] (a [khatmahDay]), to finish in
/// [days] days, the pages read and on which day ([readOn]).
class Khatmah {
  const Khatmah({
    required this.start,
    required this.days,
    this.readOn = const {},
    this.total = kKhatmahPages,
  });

  final String start;
  final int days;
  final Map<int, String> readOn;
  final int total;

  static const dayChoices = [7, 10, 15, 20, 30, 60];

  Khatmah copyWith({int? days, Map<int, String>? readOn}) => Khatmah(
    start: start,
    days: days ?? this.days,
    readOn: readOn ?? this.readOn,
    total: total,
  );

  /// [pages] read on [day] — those not read before.
  Khatmah reading(Iterable<int> pages, String day) {
    final next = {...readOn};
    var changed = false;
    for (final p in pages) {
      if (p >= 1 && p <= total && !next.containsKey(p)) {
        next[p] = day;
        changed = true;
      }
    }
    return changed ? copyWith(readOn: next) : this;
  }

  /// Every page up to [page] read (read elsewhere, on paper), on [day].
  Khatmah readThrough(int page, String day) =>
      reading([for (var p = 1; p <= page.clamp(0, total); p++) p], day);

  /// Today ([day]): the unread pages left shared over the days left
  /// (today counted; at least today), from the first unread page.
  KhatmahToday today(String day) {
    final dayIndex = _date(day)
        .difference(_date(start))
        .inDays
        .clamp(0, 1 << 30);
    final daysLeft = (days - dayIndex).clamp(1, days);
    bool readBefore(int p) => (readOn[p]?.compareTo(day) ?? 0) < 0;
    final before = readOn.keys.where(readBefore).length;
    final share = ((total - before) / daysLeft).ceil();
    // Today's portion: the first [share] pages not read before today.
    final portion = <int>[
      for (var p = 1; p <= total; p++)
        if (!readBefore(p)) p,
    ].take(share).toList();
    final readToday = portion.where((p) => readOn[p] == day).length;
    final next = portion.where((p) => !readOn.containsKey(p)).firstOrNull;
    return KhatmahToday(
      dayNo: dayIndex + 1,
      days: days,
      from: portion.firstOrNull ?? total,
      to: portion.lastOrNull ?? total,
      pages: portion.length,
      readToday: readToday,
      nextPage: next,
      read: readOn.length,
      total: total,
    );
  }

  Map<String, Object?> toJson() => {
    'start': start,
    'days': days,
    'total': total,
    // Page → the day it was read.
    'read': {for (final e in readOn.entries) '${e.key}': e.value},
  };

  static Khatmah? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['start'], days = json['days'];
    if (start is! String || days is! int || days < 1) return null;
    if (DateTime.tryParse(start) == null) return null;
    final read = <int, String>{};
    if (json['read'] case final Map m) {
      for (final e in m.entries) {
        final page = int.tryParse('${e.key}');
        if (page != null && e.value is String) read[page] = e.value as String;
      }
    }
    return Khatmah(
      start: start,
      days: days,
      readOn: read,
      total: json['total'] is int ? json['total'] as int : kKhatmahPages,
    );
  }
}

/// The khatmah's reminders from [now], [ahead] of them: each day's
/// share at [minutes] after midnight — today's only while its time is still
/// to come and its pages are not read. A future day's share is worked out
/// as if nothing more is read before it: reading in the app schedules them
/// again. Nothing once the whole Quran is read.
List<(DateTime, KhatmahToday)> khatmahReminderPlan(
  Khatmah khatmah,
  DateTime now,
  int minutes, {
  int ahead = 14,
}) {
  final plan = <(DateTime, KhatmahToday)>[];
  // Today left out: one day more, so [ahead] still come.
  for (var i = 0; plan.length < ahead && i <= ahead; i++) {
    final at = DateTime(
      now.year,
      now.month,
      now.day + i,
      minutes ~/ 60,
      minutes % 60,
    );
    final share = khatmah.today(khatmahDay(at));
    if (share.finished) break;
    if (i == 0 && (!at.isAfter(now) || share.doneToday)) continue;
    plan.add((at, share));
  }
  return plan;
}
