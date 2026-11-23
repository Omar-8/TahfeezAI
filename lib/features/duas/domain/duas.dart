import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

/// A dua in the Quran: where it is — an ayah, or a few in a row — never its
/// text (shown from the installed Quran dataset, as every ayah is; see
/// `docs/CLEAN_ROOM_RULES.md`). The ayahs are shown whole.
@immutable
class QuranDua {
  const QuranDua(this.surah, this.from, [int? to]) : to = to ?? from;

  final int surah, from, to;

  /// Its ayahs' ids (surah × 1000 + ayah), in order.
  List<int> get ayahIds => [for (var v = from; v <= to; v++) surah * 1000 + v];

  /// "2:201", "20:25–28" — left to right whatever the language around it
  /// (isolated: in Arabic "20:25–28" read as "28–20:25").
  String get reference => '\u2066$plainReference\u2069';

  /// [reference] without its direction marks.
  String get plainReference => from == to ? '$surah:$from' : '$surah:$from–$to';

  /// Its bookmark's key ([SavedSupplications]).
  String get savedKey => 'quran:$surah:$from-$to';

  @override
  bool operator ==(Object other) =>
      other is QuranDua &&
      other.surah == surah &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(surah, from, to);
}

/// A dua from Sahih al-Bukhari or Sahih Muslim, as Tahfeez bundles it
/// (`tool/duas/build_hadith_duas.py`, fawazahmed0/hadith-api): the whole
/// hadith in Arabic, its translations by language code, the Duas section
/// it is shown in.
@immutable
class HadithDua {
  const HadithDua({
    required this.book,
    required this.number,
    required this.group,
    required this.arabic,
    required this.translations,
    required this.titleEn,
    required this.titleAr,
  });

  factory HadithDua.fromJson(Map<String, Object?> json) => HadithDua(
    book: json['book']! as String,
    number: json['number']! as String,
    group: json['group']! as String,
    arabic: json['ar']! as String,
    translations: (json['tr']! as Map<String, Object?>).cast<String, String>(),
    titleEn: json['titleEn']! as String,
    titleAr: json['titleAr']! as String,
  );

  /// `bukhari` or `muslim`.
  final String book;

  /// Its number: Bukhari's, or Muslim's ʿAbd al-Baqi number with its
  /// narration ("2721.01").
  final String number;

  /// Its [DuaGroup]'s name.
  final String group;
  final String arabic;
  final Map<String, String> translations;

  /// Tahfeez's own short title for its tile (as Hisn al-Muslim's chapters
  /// have), in English and Arabic.
  final String titleEn, titleAr;

  /// Its title in the app's language: the Arabic in Arabic, else the
  /// English.
  String titleIn(String language) => language == 'ar' ? titleAr : titleEn;

  /// "6306", "2721a" (as sunnah.com numbers a narration).
  String get shownNumber {
    final [whole, ...rest] = number.split('.');
    if (rest.isEmpty) return whole;
    final n = int.parse(rest.first);
    return '$whole${String.fromCharCode(96 + n)}';
  }

  /// Its translation in [language] — English where there is none (`null`
  /// in Arabic: the hadith is Arabic).
  String? translationIn(String language) =>
      language == 'ar' ? null : translations[language] ?? translations['en'];

  /// Its bookmark's key ([SavedSupplications]).
  String get savedKey => 'hadith:$book:$number';
}

/// The Duas page's sections (owner, 2026-11-23: money, health, children,
/// marriage…): Tahfeez's own choice of the Quran's duas — the ayahs only,
/// checked against the dataset's text (each one a supplication) — and of
/// Hisn al-Muslim's chapters (the Athkar's, by their IDs).
enum DuaGroup {
  health(Icons.healing_outlined, [QuranDua(21, 83)], [124, 49, 51, 83, 125]),
  provision(
    Icons.payments_outlined,
    [QuranDua(2, 201), QuranDua(28, 24), QuranDua(5, 114), QuranDua(23, 29)],
    [41, 91, 90, 98],
  ),
  marriage(Icons.favorite_border_rounded, [QuranDua(25, 74)], [79, 80, 81]),
  children(
    Icons.child_care_outlined,
    [
      QuranDua(3, 38),
      QuranDua(37, 100),
      QuranDua(21, 89),
      QuranDua(14, 40),
      QuranDua(46, 15),
      QuranDua(2, 128),
    ],
    [47, 48],
  ),
  parents(Icons.elderly_outlined, [
    QuranDua(17, 24),
    QuranDua(14, 41),
    QuranDua(71, 28),
    QuranDua(27, 19),
  ], []),
  distress(
    Icons.support_outlined,
    [
      QuranDua(21, 87),
      QuranDua(20, 25, 28),
      QuranDua(9, 129),
      QuranDua(2, 286),
      QuranDua(2, 250),
      QuranDua(7, 126),
    ],
    [34, 35, 43, 46, 53, 126],
  ),
  forgiveness(
    Icons.water_drop_outlined,
    [
      QuranDua(7, 23),
      QuranDua(28, 16),
      QuranDua(3, 16),
      QuranDua(3, 147),
      QuranDua(3, 193),
      QuranDua(23, 109),
      QuranDua(23, 118),
      QuranDua(59, 10),
    ],
    [129, 44],
  ),
  guidance(
    Icons.lightbulb_outline_rounded,
    [
      QuranDua(20, 114),
      QuranDua(3, 8),
      QuranDua(18, 10),
      QuranDua(2, 127),
      QuranDua(26, 83),
      QuranDua(3, 53),
      QuranDua(12, 101),
    ],
    [26, 40],
  ),
  protection(
    Icons.shield_outlined,
    [
      QuranDua(23, 97, 98),
      QuranDua(10, 85, 86),
      QuranDua(60, 5),
      QuranDua(7, 47),
    ],
    [36, 37, 38, 39, 45, 128, 88, 94, 92],
  ),
  hereafter(Icons.park_outlined, [
    QuranDua(25, 65, 66),
    QuranDua(66, 11),
    QuranDua(3, 194),
    QuranDua(26, 85),
    QuranDua(26, 87),
  ], []),
  travel(
    Icons.flight_takeoff_rounded,
    [QuranDua(43, 13, 14), QuranDua(17, 80)],
    [95, 96, 97, 104, 105, 100, 101],
  ),
  deceased(Icons.local_florist_outlined, [], [52, 54, 55, 56, 57, 58, 59, 60]);

  const DuaGroup(this.icon, this.quran, this.chapters);

  /// Its hadith duas, of [all] (the bundled ones), in their order.
  List<HadithDua> hadithsOf(List<HadithDua> all) => [
    for (final h in all)
      if (h.group == name) h,
  ];

  final IconData icon;

  /// Its duas from the Quran, in the order shown.
  final List<QuranDua> quran;

  /// Its Hisn al-Muslim chapters (IDs), in the order shown.
  final List<int> chapters;

  String title(AppLocalizations l10n) => switch (this) {
    health => l10n.duasGroupHealth,
    provision => l10n.duasGroupProvision,
    marriage => l10n.duasGroupMarriage,
    children => l10n.duasGroupChildren,
    parents => l10n.duasGroupParents,
    distress => l10n.duasGroupDistress,
    forgiveness => l10n.duasGroupForgiveness,
    guidance => l10n.duasGroupGuidance,
    protection => l10n.duasGroupProtection,
    hereafter => l10n.duasGroupHereafter,
    travel => l10n.duasGroupTravel,
    deceased => l10n.duasGroupDeceased,
  };

  /// The first group with [dua].
  static DuaGroup? of(QuranDua dua) {
    for (final g in values) {
      if (g.quran.contains(dua)) return g;
    }
    return null;
  }

  /// Every Quran dua, once each, in the groups' order.
  static List<QuranDua> get allQuran =>
      {for (final g in values) ...g.quran}.toList();

  /// [key]'s Quran dua ([QuranDua.savedKey]), if it is one of them.
  static QuranDua? quranOf(String key) {
    for (final d in allQuran) {
      if (d.savedKey == key) return d;
    }
    return null;
  }
}
