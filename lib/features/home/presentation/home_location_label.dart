import '../../../core/localization/generated/app_localizations.dart';
import '../../../quran/domain/models/quran_location.dart';

/// A short, localized name for a place in the Quran, for Home's cards:
/// the chapter's name and ayah where there is one, else its page, Juz or
/// Hizb.
String homeLocationLabel(
  AppLocalizations l10n,
  QuranLocation location, {
  String? chapterName,
}) {
  String chapter(int surahNo) =>
      chapterName ?? l10n.homeContinueReadingSurah(surahNo);
  return switch (location) {
    QuranLocationSurah(:final surahNo) => chapter(surahNo),
    QuranLocationAyah(:final chapterNo, :final verseNo) =>
      l10n.homeDailyAyahReferenceNamed(chapter(chapterNo), verseNo),
    QuranLocationAyahRange(:final chapterNo, :final fromVerseNo) =>
      l10n.homeDailyAyahReferenceNamed(chapter(chapterNo), fromVerseNo),
    QuranLocationJuz(:final juzNo) => l10n.homeContinueReadingJuz(juzNo),
    QuranLocationHizb(:final hizbNo) => l10n.homeContinueReadingHizb(hizbNo),
    QuranLocationPage(:final pageNumber) => l10n.homeContinueReadingPage(
      pageNumber,
    ),
  };
}
