import 'package:freezed_annotation/freezed_annotation.dart';

part 'surah_models.freezed.dart';

/// Where a chapter was revealed. The Quran has exactly two revelation
/// places; this is an immutable fact about the Quran, not a reference-app
/// detail.
enum RevelationType { meccan, medinan }

/// A chapter (Surah) of the Quran — canonical, immutable metadata only. No
/// translation/localization text lives here; see [SurahLocalization].
@freezed
abstract class Surah with _$Surah {
  const factory Surah({
    /// 1-based chapter number (1-114).
    required int surahNo,
    required int ayahCount,

    /// Position of this chapter in the order it was revealed (distinct from
    /// [surahNo], which is the chapter's position in Mushaf/reading order).
    required int revelationOrder,
    required int rukusCount,
    required RevelationType revelationType,
  }) = _Surah;
}

/// Per-language display metadata for a [Surah] (name and its meaning),
/// stored separately from canonical structural data because translation
/// coverage varies by language and is independently maintainable.
@freezed
abstract class SurahLocalization with _$SurahLocalization {
  const factory SurahLocalization({
    required int surahNo,
    required String languageCode,
    required String name,

    /// The chapter name's meaning/translation (e.g. "The Opening" for
    /// Al-Fatiha), when available for this language.
    String? meaning,
  }) = _SurahLocalization;
}
