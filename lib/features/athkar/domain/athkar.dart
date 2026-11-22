import 'package:flutter/foundation.dart';

/// One zikr of Hisn al-Muslim: its Arabic, its English (translation and a
/// note — its transliteration, or how to say it), how many times it is
/// said, and its audio on hisnmuslim.com (if it has one).
@immutable
class Zikr {
  const Zikr({
    required this.id,
    required this.arabic,
    required this.english,
    required this.note,
    required this.repeat,
    required this.audio,
  });

  factory Zikr.fromJson(Map<String, Object?> json) => Zikr(
    id: json['id']! as int,
    arabic: json['ar']! as String,
    english: json['en']! as String,
    note: json['note']! as String,
    repeat: json['repeat']! as int,
    audio: json['audio'] as String?,
  );

  final int id;
  final String arabic, english, note;

  /// How many times it is said (at least once).
  final int repeat;

  /// Its file under hisnmuslim.com's /audio/ar/ — `null`: none.
  final String? audio;
}

/// One of the book's chapters ("Words of remembrance for morning and
/// evening"): its title in Arabic and English, its athkar, and the audio of
/// the whole of it.
@immutable
class AthkarCategory {
  const AthkarCategory({
    required this.id,
    required this.arabic,
    required this.english,
    required this.audio,
    required this.athkar,
    this.shortArabic,
    this.shortEnglish,
  });

  factory AthkarCategory.fromJson(Map<String, Object?> json) => AthkarCategory(
    id: json['id']! as int,
    arabic: json['ar']! as String,
    english: json['en']! as String,
    shortArabic: json['arShort'] as String?,
    shortEnglish: json['enShort'] as String?,
    audio: json['audio']! as String,
    athkar: [
      for (final z in json['items']! as List<Object?>)
        Zikr.fromJson(z! as Map<String, Object?>),
    ],
  );

  final int id;

  /// The book's titles.
  final String arabic, english;

  /// Tahfeez's own short titles (owner, 2026-11-21: the book's too long
  /// for a tile) — `null`: the book's is short enough.
  final String? shortArabic, shortEnglish;

  /// Its file under hisnmuslim.com's /audio/ar/.
  final String audio;
  final List<Zikr> athkar;

  /// Its name in the app's language — short: the Arabic in Arabic, else
  /// the English (the only translation the source has).
  String titleIn(String languageCode) =>
      languageCode == 'ar' ? shortArabic ?? arabic : shortEnglish ?? english;

  /// The book's own title, in full.
  String fullTitleIn(String languageCode) =>
      languageCode == 'ar' ? arabic : english;
}

/// Hisn al-Muslim, as the app bundles it.
@immutable
class AthkarBook {
  AthkarBook(this.categories) : _byId = {for (final c in categories) c.id: c};

  factory AthkarBook.fromJson(Map<String, Object?> json) => AthkarBook([
    for (final c in json['categories']! as List<Object?>)
      AthkarCategory.fromJson(c! as Map<String, Object?>),
  ]);

  final List<AthkarCategory> categories;
  final Map<int, AthkarCategory> _byId;

  AthkarCategory? category(int id) => _byId[id];

  /// The categories with Morning & Evening's athkar.
  static const morningEvening = 27;
}

/// Where a category's or a zikr's audio is (hisnmuslim.com, https).
Uri athkarAudioUri(String file) =>
    Uri.https('www.hisnmuslim.com', '/audio/ar/$file');
