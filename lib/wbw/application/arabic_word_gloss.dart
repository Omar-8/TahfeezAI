import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quran/application/quran_script_code.dart';
import '../../quran/quran_providers.dart';
import '../../quran/tafsir_providers.dart';

/// al-Sirāj's tafsir (the meanings of each ayah's difficult words, in
/// Arabic), bundled: `docs/THIRD_PARTY_RESOURCES.md`.
const sirajTafsirId = 'ar-seraj';

/// Matches al-Sirāj's notes to an ayah's words. Each note is a line
/// «headword: meaning», the headword in the common (imlāʾī) spelling of one
/// or more of the ayah's words — compared without vowel marks, the alef's
/// forms as one, and a letter's difference allowed (the Mushaf's own
/// spelling, «ٱلصَّلَوٰةَ» for «الصَّلَاةَ»).
abstract final class SirajGlosses {
  /// The meaning of the ayah's word at [wordIndex] (of [ayahWords]) in
  /// [note] (the ayah's al-Sirāj text), or `null` where it has none.
  static String? forWord(String note, List<String> ayahWords, int wordIndex) {
    final words = [for (final w in ayahWords) normalize(w)];
    for (final line in note.split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final head = [
        for (final w in line.substring(0, colon).split(RegExp(r'\s+')))
          if (normalize(w).isNotEmpty) normalize(w),
      ];
      final meaning = line.substring(colon + 1).trim();
      if (head.isEmpty || meaning.isEmpty) continue;
      for (var start = 0; start + head.length <= words.length; start++) {
        var all = true;
        for (var k = 0; k < head.length && all; k++) {
          all = _same(head[k], words[start + k]);
        }
        if (all && wordIndex >= start && wordIndex < start + head.length) {
          return meaning;
        }
      }
    }
    return null;
  }

  static final _marks = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]',
  );

  /// [word]'s letters only: no vowel marks, Quranic signs or tatweel; the
  /// alef's forms as «ا», «ى» as «ي», «ة» as «ه».
  static String normalize(String word) => word
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[ٱأإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^ء-ي]'), '');

  static bool _same(String head, String word) {
    if (head == word) return true;
    // A prefixed «و» / «ف» the note leaves out.
    if (word.length > head.length &&
        (word.startsWith('و') || word.startsWith('ف')) &&
        _close(head, word.substring(1))) {
      return true;
    }
    return _close(head, word);
  }

  /// Equal but for one letter (added, dropped or changed), in words of
  /// four letters or more.
  static bool _close(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4 || (a.length - b.length).abs() > 1) {
      return false;
    }
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (b.length > a.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }
}

/// The word's meaning in Arabic from al-Sirāj, where it explains it.
final arabicWordGlossProvider =
    FutureProvider.family<String?, ({int ayahId, int wordIndex})>((
      ref,
      word,
    ) async {
      final note = await ref.watch(tafsirRepositoryProvider).getVerseText((
        chapterNo: word.ayahId ~/ 1000,
        verseNo: word.ayahId % 1000,
      ), tafsirId: sirajTafsirId);
      if (note == null || note.text.isEmpty) return null;
      final words = await ref
          .watch(quranRepositoryProvider)
          .getWordsForAyah(
            word.ayahId,
            scriptCode: ref.watch(quranScriptCodeProvider),
          );
      return SirajGlosses.forWord(note.text, [
        for (final w in words) w.text,
      ], word.wordIndex);
    });
