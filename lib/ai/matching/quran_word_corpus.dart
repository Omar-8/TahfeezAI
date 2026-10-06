import '../../quran/domain/models/quran_refs.dart';
import 'quran_match_normalizer.dart';

/// One canonical word in reading order, with its match keys.
class CorpusWord {
  const CorpusWord({
    required this.ref,
    required this.verse,
    required this.text,
    required this.key,
    required this.skeleton,
    this.spoken,
  });

  final WordRef ref;
  final VerseRef verse;

  /// Canonical text, for logging only.
  final String text;
  final String key;
  final String skeleton;

  /// For the disjointed letters (muqaṭṭaʿāt) that open 29 surahs: the
  /// letters' spoken names run together, as recognizers write them
  /// («يسٓ» → `ياسين`, «الٓمٓ» → `الفلامميم`). `null` for every other word.
  final String? spoken;
}

/// Spoken names of the letters used in the muqaṭṭaʿāt, spelled as
/// recognizers write them (after [QuranMatchNormalizer.key]).
const _letterNames = {
  'ا': 'الف',
  'ل': 'لام',
  'م': 'ميم',
  'ص': 'صاد',
  'ر': 'را',
  'ك': 'كاف',
  'ه': 'ها',
  'ي': 'يا',
  'ع': 'عين',
  'ط': 'طا',
  'س': 'سين',
  'ح': 'حا',
  'ق': 'قاف',
  'ن': 'نون',
};

/// Where the muqaṭṭaʿāt are: the first word of these ayahs. Listed
/// explicitly — «الم» is also an ordinary word («أَلَمْ») everywhere else.
const _muqattaat = <(int, int)>{
  (2, 1),
  (3, 1),
  (7, 1),
  (10, 1),
  (11, 1),
  (12, 1),
  (13, 1),
  (14, 1),
  (15, 1),
  (19, 1),
  (20, 1),
  (26, 1),
  (27, 1),
  (28, 1),
  (29, 1),
  (30, 1),
  (31, 1),
  (32, 1),
  (36, 1),
  (38, 1),
  (40, 1),
  (41, 1),
  (42, 1),
  (42, 2),
  (43, 1),
  (44, 1),
  (45, 1),
  (46, 1),
  (50, 1),
  (68, 1),
};

String? _spokenLetters(String key) {
  final names = [for (final c in key.split('')) _letterNames[c]];
  return names.contains(null) ? null : names.join();
}

/// The whole Quran as one sequence of canonical words (Tahfeez's own
/// [WordRef]/[VerseRef] identities), addressed by *position* — 0 for the
/// first word of Al-Fātiḥah, up to [length] - 1 — so the matcher can move
/// forward and back across ayah and surah boundaries.
class QuranWordCorpus {
  QuranWordCorpus._(this.words, this._positionByRef, this._verseStart)
    : _bySkeleton = _index(words);

  /// Builds the corpus from canonical words; [words] need not be sorted.
  factory QuranWordCorpus.fromWords(
    Iterable<({WordRef ref, VerseRef verse, String text})> words, {
    QuranMatchNormalizer normalizer = const QuranMatchNormalizer(),
  }) {
    final sorted = words.toList()
      ..sort((a, b) {
        final byVerse = a.verse.chapterNo != b.verse.chapterNo
            ? a.verse.chapterNo - b.verse.chapterNo
            : a.verse.verseNo - b.verse.verseNo;
        return byVerse != 0 ? byVerse : a.ref.wordIndex - b.ref.wordIndex;
      });
    final list = <CorpusWord>[];
    final positions = <WordRef, int>{};
    final verseStart = <VerseRef, int>{};
    for (final w in sorted) {
      final key = normalizer.key(w.text);
      positions[w.ref] = list.length;
      verseStart.putIfAbsent(w.verse, () => list.length);
      final isMuqattaat =
          w.ref.wordIndex == 0 &&
          _muqattaat.contains((w.verse.chapterNo, w.verse.verseNo));
      list.add(
        CorpusWord(
          ref: w.ref,
          verse: w.verse,
          text: w.text,
          key: key,
          skeleton: normalizer.skeleton(key),
          spoken: isMuqattaat ? _spokenLetters(key) : null,
        ),
      );
    }
    return QuranWordCorpus._(list, positions, verseStart);
  }

  final List<CorpusWord> words;
  final Map<WordRef, int> _positionByRef;
  final Map<VerseRef, int> _verseStart;
  final Map<String, List<int>> _bySkeleton;

  int get length => words.length;

  int? positionOf(WordRef ref) => _positionByRef[ref];

  /// Position of the first word of [verse].
  int? verseStartPosition(VerseRef verse) => _verseStart[verse];

  /// Position of the last word of [verse].
  int? verseEndPosition(VerseRef verse) {
    final start = _verseStart[verse];
    if (start == null) return null;
    var p = start;
    while (p + 1 < words.length && words[p + 1].verse == verse) {
      p++;
    }
    return p;
  }

  /// Positions of every word whose alef-free skeleton equals [skeleton].
  List<int> positionsWithSkeleton(String skeleton) =>
      _bySkeleton[skeleton] ?? const [];

  static Map<String, List<int>> _index(List<CorpusWord> words) {
    final index = <String, List<int>>{};
    const n = QuranMatchNormalizer();
    for (var p = 0; p < words.length; p++) {
      (index[words[p].skeleton] ??= []).add(p);
      final spoken = words[p].spoken;
      if (spoken != null) (index[n.skeleton(spoken)] ??= []).add(p);
    }
    return index;
  }
}
