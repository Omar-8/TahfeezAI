/// What the home-screen widgets show (owner, 2026-11-22): everything they
/// need, already in the app's language — Android's and the iPhone's own
/// widget code only draws it and opens the routes. Days ahead are included
/// (prayer times, Hijri dates; the daily ayah by its date-seeded rule), so
/// the widgets stay right while the app isn't opened.
library;

import 'dart:convert';

/// The widgets the app offers, by their key in the payload and in the
/// widget code of both platforms.
enum HomeWidgetKind {
  home,
  today,
  prayer,
  qibla,
  athkar,
  habits,
  shortcuts,
  shortcutsSmall,
  ayah,
  reading,
  date,
  memorize,
  khatmah,
  quran,
}

/// One day of prayer times: its date (`2026-11-22`) and, per time in
/// [PrayerDays.order], when (epoch ms) and how it reads ("4:54 AM").
typedef PrayerDay = ({String date, List<int> at, List<String> shown});

class PrayerDays {
  const PrayerDays({
    required this.place,
    required this.names,
    required this.order,
    required this.days,
  });

  /// "Cairo, Egypt" (or the app's word for the phone's position).
  final String place;

  /// Each time's name, in [order].
  final List<String> names;

  /// The times' keys: `fajr`, `sunrise`, `dhuhr`, `asr`, `maghrib`,
  /// `isha` (Home's six).
  final List<String> order;
  final List<PrayerDay> days;

  Map<String, Object?> toJson() => {
    'place': place,
    'names': names,
    'order': order,
    'days': [
      for (final d in days) {'date': d.date, 'at': d.at, 'shown': d.shown},
    ],
  };
}

/// One of the daily ayahs, as its widget shows it: the verified text (its
/// words in the dataset's Uthmani script, never generated), its reference,
/// a translation and the route to it.
typedef WidgetAyah = ({
  String text,
  String reference,
  String? translation,
  String route,
});

/// A row of today's memorization: what it is, how far, whether done.
typedef MemorizeRow = ({String title, String value, bool done});

class HomeWidgetPayload {
  const HomeWidgetPayload({
    required this.language,
    required this.rtl,
    this.theme = 'system',
    this.clock = 'system',
    required this.updated,
    required this.labels,
    required this.routes,
    this.prayer,
    this.ayahs = const [],
    this.ayahEpoch = '2024-01-01',
    this.dates = const [],
    this.reading,
    this.memorize,
    this.khatmah,
    this.until = const [],
  });

  /// The app's language, and whether it is written right to left.
  final String language;
  final bool rtl;

  /// `light`, `dark`, or `system` (the phone's): the app's own theme
  /// (owner, 2026-11-22: the widgets as the app).
  final String theme;

  /// `12`, `24`, or `system` (the phone's): the app's time format (owner,
  /// 2026-11-22).
  final String clock;

  /// When this was written.
  final DateTime updated;

  /// The texts the widgets show (titles, buttons), by key.
  final Map<String, String> labels;

  /// Where each widget opens, by [HomeWidgetKind] name.
  final Map<String, String> routes;

  /// `null`: no place yet — the widget asks to open prayer times.
  final PrayerDays? prayer;

  /// The daily ayahs in order: day `n` after [ayahEpoch] shows
  /// `ayahs[n % length]` (the app's own rule, dailyAyahVerseForDate).
  final List<WidgetAyah> ayahs;
  final String ayahEpoch;

  /// Days ahead, each its date, its Gregorian date, its Hijri date in
  /// words and its Hijri day, and a Hijri event coming ("ʿArafah in 2
  /// days"), as Home's date card shows them.
  final List<
    ({
      String date,
      String gregorian,
      String gregorianShort,
      String hijri,
      String hijriShort,
      int hijriDay,
      String? event,
    })
  >
  dates;

  /// Where reading goes on: a title, a line under it; `null` when nothing
  /// was read yet.
  final ({String title, String subtitle})? reading;

  /// Today's memorization (as of [memorize]'s date): its rows and parts
  /// done; `null` without a plan.
  final ({String date, int done, int total, List<MemorizeRow> rows})? memorize;

  /// "36 min", "1 h 5 min": the time until the next prayer in the app's
  /// words, for each whole minute from 0 (the widgets count down by the
  /// minute; the plural forms of each language are the app's).
  final List<String> until;

  /// Today's khatmah portion; `null` without a khatmah.
  final ({String date, String title, String line, double progress})? khatmah;

  Map<String, Object?> toJson() => {
    'v': 1,
    'language': language,
    'rtl': rtl,
    'theme': theme,
    'clock': clock,
    'updated': updated.millisecondsSinceEpoch,
    'labels': labels,
    'routes': routes,
    'prayer': prayer?.toJson(),
    'ayahs': [
      for (final a in ayahs)
        {
          'text': a.text,
          'reference': a.reference,
          'translation': a.translation,
          'route': a.route,
        },
    ],
    'ayahEpoch': ayahEpoch,
    'until': until,
    'dates': [
      for (final d in dates)
        {
          'date': d.date,
          'gregorian': d.gregorian,
          'gregorianShort': d.gregorianShort,
          'hijri': d.hijri,
          'hijriShort': d.hijriShort,
          'hijriDay': d.hijriDay,
          'event': d.event,
        },
    ],
    'reading': switch (reading) {
      final r? => {'title': r.title, 'subtitle': r.subtitle},
      null => null,
    },
    'memorize': switch (memorize) {
      final m? => {
        'date': m.date,
        'done': m.done,
        'total': m.total,
        'rows': [
          for (final r in m.rows)
            {'title': r.title, 'value': r.value, 'done': r.done},
        ],
      },
      null => null,
    },
    'khatmah': switch (khatmah) {
      final k? => {
        'date': k.date,
        'title': k.title,
        'line': k.line,
        'progress': k.progress,
      },
      null => null,
    },
  };

  String encode() => jsonEncode(toJson());
}

/// `2026-11-22`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The route a widget link carries (`tahfeezwidget://open?route=/prayer`),
/// if it is one of the app's own (a path; nothing else is followed).
String? homeWidgetRoute(Uri? uri) {
  final route = uri?.queryParameters['route'];
  if (route == null || !route.startsWith('/') || route.startsWith('//')) {
    return null;
  }
  return route;
}
