import 'dart:convert';
import 'dart:io';

import 'package:tahfeez_ai/ai/matching/quran_word_corpus.dart';

QuranWordCorpus? _corpus;

/// The real canonical corpus, read straight from the bundled dataset (the
/// same Tanzil Uthmani words the app loads into its database).
QuranWordCorpus loadTestCorpus() {
  return _corpus ??= () {
    final data = jsonDecode(
      File('assets/quran/quran_dataset.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final verses = {
      for (final a in (data['ayahs']! as List).cast<Map<String, Object?>>())
        a['id']! as int: (
          chapterNo: a['chapterNo']! as int,
          verseNo: a['verseNo']! as int,
        ),
    };
    return QuranWordCorpus.fromWords([
      for (final w in (data['ayahWords']! as List).cast<Map<String, Object?>>())
        (
          ref: (ayahId: w['ayahId']! as int, wordIndex: w['wordIndex']! as int),
          verse: verses[w['ayahId']]!,
          text: w['text']! as String,
        ),
    ]);
  }();
}
