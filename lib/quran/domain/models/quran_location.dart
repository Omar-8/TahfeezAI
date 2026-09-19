import 'package:freezed_annotation/freezed_annotation.dart';

part 'quran_location.freezed.dart';

/// A single, unified way to point at "somewhere in the Quran" — a chapter,
/// a verse, a verse range, a Juz, a Hizb, or a Mushaf page.
///
/// This is Milestone 5's "unified location model": every screen that lets a
/// user jump into Quran content (the index, search results, bookmarks,
/// deep links, and eventually the Reader itself) is meant to describe its
/// target as one of these variants rather than inventing its own per-screen
/// navigation argument shape. See
/// `lib/quran/domain/quran_location_path.dart` for the deep-link-safe
/// string encoding built on top of this type.
@freezed
sealed class QuranLocation with _$QuranLocation {
  const factory QuranLocation.surah(int surahNo) = QuranLocationSurah;

  const factory QuranLocation.ayah(int chapterNo, int verseNo) =
      QuranLocationAyah;

  const factory QuranLocation.ayahRange(
    int chapterNo,
    int fromVerseNo,
    int toVerseNo,
  ) = QuranLocationAyahRange;

  const factory QuranLocation.juz(int juzNo) = QuranLocationJuz;

  const factory QuranLocation.hizb(int hizbNo) = QuranLocationHizb;

  const factory QuranLocation.page(int mushafId, int pageNumber) =
      QuranLocationPage;
}
