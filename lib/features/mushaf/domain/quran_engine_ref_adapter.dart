import '../../../quran/domain/models/quran_refs.dart';

/// The single place Quran Engine's own key format
/// (`"surah:ayah"`/`"surah:ayah:word"`, as reported by both the Android
/// wrapper's `word.wordKey`/`hit.wordKey` and the Web JS runtime's
/// `hitTestViewEx`/`wordKey`) is ever parsed, and the only place a Quran
/// Engine word/ayah index is ever converted into one of Tahfeez's existing
/// canonical reference types — [WordRef]/[VerseRef]
/// (`lib/quran/domain/models/quran_refs.dart`), not new Mushaf-backend-
/// specific types, since Tahfeez already has exactly this concept and nothing
/// about Quran Engine changes what a word or verse *is*.
///
/// No other file may split a Quran Engine key string on `:` — every call
/// site (the Android adapter, the Web bridge, the Mushaf page content
/// widget, tests) goes through this adapter, so the key format is a fact
/// about this one file, not a convention every caller has to remember.
///
/// Quran Engine reports both axes 1-based (confirmed against real
/// `NNN.words.json` sidecar data — page 1's first word is `"1:1:1"`).
/// [WordRef.wordIndex] is 0-based, matching every other canonical word
/// index in this codebase (`AyahWord.wordIndex`, `WordRef.wordIndex`) — see
/// `lib/quran/domain/models/quran_refs.dart`'s own doc comment.
abstract final class QuranEngineRefAdapter {
  /// Tahfeez's stable ayah id, `chapterNo * 1000 + verseNo` — the same
  /// formula documented on `Ayah.id`
  /// (`lib/quran/domain/models/ayah_models.dart`) and used throughout the
  /// reader (`ReaderSessionController`, `MushafPageTranslations`,
  /// `WordDetailSheet`) — never recomputed differently here.
  static int ayahIdOf({required int surahNo, required int ayahNo}) =>
      surahNo * 1000 + ayahNo;

  static VerseRef verseRefOf({required int surahNo, required int ayahNo}) =>
      (chapterNo: surahNo, verseNo: ayahNo);

  /// Parses `"surah:ayah"` (as used for an ayah-level target/hit) into a
  /// canonical [VerseRef]. Throws [FormatException] on anything else —
  /// never silently returns a guessed/zeroed reference.
  static VerseRef verseRefFromEngineKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) {
      throw FormatException('Expected "surah:ayah", got "$key"', key);
    }
    return verseRefOf(
      surahNo: int.parse(parts[0]),
      ayahNo: int.parse(parts[1]),
    );
  }

  /// Parses `"surah:ayah:word"` (Quran Engine's 1-based word-in-ayah index)
  /// into a canonical [WordRef] (0-based [WordRef.wordIndex]). Throws
  /// [FormatException] on anything else.
  static WordRef wordRefFromEngineKey(String key) {
    final parts = key.split(':');
    if (parts.length != 3) {
      throw FormatException('Expected "surah:ayah:word", got "$key"', key);
    }
    final surahNo = int.parse(parts[0]);
    final ayahNo = int.parse(parts[1]);
    final engineWordIndex = int.parse(parts[2]);
    return (
      ayahId: ayahIdOf(surahNo: surahNo, ayahNo: ayahNo),
      wordIndex: engineWordIndex - 1,
    );
  }

  /// The inverse of [wordRefFromEngineKey]'s word-index convention — builds
  /// the `"surah:ayah:word"` key Quran Engine's own `T.word`/`T.ayah`-style
  /// target builders expect, from a canonical [WordRef]. `ayahId` is
  /// decomposed via the same `chapterNo * 1000 + verseNo` convention
  /// [ayahIdOf] uses, inverted.
  static String engineKeyFromWordRef(WordRef ref) {
    final surahNo = ref.ayahId ~/ 1000;
    final ayahNo = ref.ayahId % 1000;
    return '$surahNo:$ayahNo:${ref.wordIndex + 1}';
  }
}
