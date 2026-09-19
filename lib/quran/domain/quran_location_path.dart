import 'models/quran_location.dart';

/// Encodes [location] as a deep-link-safe, URL-path-shaped string with no
/// leading slash (e.g. `surah/2`, `ayah/2/255`, `juz/5`, `page/1/42`) — the
/// single canonical serialization [QuranLocation] has. `core/routing`
/// mounts these as literal `go_router` path templates under `/quran/…`, and
/// the same string is what `lib/features/quran/application/`'s "recent
/// location" persistence stores, so there is exactly one encoding to keep
/// in sync rather than one per consumer.
String quranLocationPath(QuranLocation location) {
  return switch (location) {
    QuranLocationSurah(:final surahNo) => 'surah/$surahNo',
    QuranLocationAyah(:final chapterNo, :final verseNo) =>
      'ayah/$chapterNo/$verseNo',
    QuranLocationAyahRange(
      :final chapterNo,
      :final fromVerseNo,
      :final toVerseNo,
    ) =>
      'ayah-range/$chapterNo/$fromVerseNo/$toVerseNo',
    QuranLocationJuz(:final juzNo) => 'juz/$juzNo',
    QuranLocationHizb(:final hizbNo) => 'hizb/$hizbNo',
    QuranLocationPage(:final mushafId, :final pageNumber) =>
      'page/$mushafId/$pageNumber',
  };
}

/// The inverse of [quranLocationPath]. Returns `null` for anything that
/// isn't a well-formed encoding (an unknown kind, a missing/non-integer
/// segment) rather than throwing, since its main caller (restoring a
/// persisted "recent location") must tolerate a value written by a future
/// app version it doesn't recognize.
QuranLocation? quranLocationFromPath(String path) {
  final segments = path.split('/');
  int? parseInt(String s) => int.tryParse(s);

  switch (segments) {
    case [final kind, final a] when kind == 'surah':
      final surahNo = parseInt(a);
      return surahNo == null ? null : QuranLocation.surah(surahNo);
    case [final kind, final a] when kind == 'juz':
      final juzNo = parseInt(a);
      return juzNo == null ? null : QuranLocation.juz(juzNo);
    case [final kind, final a] when kind == 'hizb':
      final hizbNo = parseInt(a);
      return hizbNo == null ? null : QuranLocation.hizb(hizbNo);
    case [final kind, final a, final b] when kind == 'ayah':
      final chapterNo = parseInt(a);
      final verseNo = parseInt(b);
      return (chapterNo == null || verseNo == null)
          ? null
          : QuranLocation.ayah(chapterNo, verseNo);
    case [final kind, final a, final b] when kind == 'page':
      final mushafId = parseInt(a);
      final pageNumber = parseInt(b);
      return (mushafId == null || pageNumber == null)
          ? null
          : QuranLocation.page(mushafId, pageNumber);
    case [final kind, final a, final b, final c] when kind == 'ayah-range':
      final chapterNo = parseInt(a);
      final fromVerseNo = parseInt(b);
      final toVerseNo = parseInt(c);
      return (chapterNo == null || fromVerseNo == null || toVerseNo == null)
          ? null
          : QuranLocation.ayahRange(chapterNo, fromVerseNo, toVerseNo);
    default:
      return null;
  }
}
