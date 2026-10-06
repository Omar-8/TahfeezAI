/// Folds Arabic words into comparison keys for matching speech-recognition
/// output against canonical (Tanzil Uthmani) Quran words.
///
/// Recognizers write ordinary (imlāʾī) spelling without diacritics, while
/// the canonical text is Uthmani script. Two keys absorb the difference:
///
/// - [key]: diacritics and Quranic annotation marks removed, the
///   superscript ("dagger") alef turned into a real alef, hamza carriers
///   and alef forms folded, ة→ه, ى→ي. Uthmani «ٱلسَّمَٰوَٰتِ» and spoken
///   «السماوات» both become `السماوات`.
/// - [skeleton]: [key] without any alef, for words where one spelling
///   writes an alef the other doesn't (Uthmani «هَٰذَا» `هاذا` vs «هذا»).
///
/// Keys are derived match data only — canonical text is never modified or
/// displayed from them (see `docs/CLEAN_ROOM_RULES.md`).
class QuranMatchNormalizer {
  const QuranMatchNormalizer();

  // Harakat, tanwin, shadda, sukun, maddah, hamza above/below, and the
  // Quranic annotation block (small high/low letters, stop signs) — plus
  // tatweel and the small waw/yeh of pronounced lengthening.
  static final _marks = RegExp('[ً-ٟۖ-ۭـ]');
  static final _nonLetters = RegExp('[^ء-يٱ]');

  /// Comparison key; empty for input with no Arabic letters.
  String key(String word) {
    var s = word.replaceAll('ٰ', 'ا'); // superscript alef is pronounced
    s = s.replaceAll(_marks, '');
    s = s.replaceAll(_nonLetters, '');
    final out = StringBuffer();
    for (final rune in s.runes) {
      final folded = switch (rune) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 'ا', // آ أ إ ٱ
        0x0624 => 'و', // ؤ
        0x0626 || 0x0649 => 'ي', // ئ ى
        0x0629 => 'ه', // ة
        0x0621 => '', // standalone ء
        _ => String.fromCharCode(rune),
      };
      out.write(folded);
    }
    return out.toString();
  }

  /// [key] with every alef removed.
  String skeleton(String key) => key.replaceAll('ا', '');

  /// Splits recognizer output into comparison keys, dropping tokens with no
  /// Arabic letters (punctuation, digits, Latin).
  List<String> keysOf(String transcript) => [
    for (final token in transcript.split(RegExp(r'\s+')))
      if (key(token) case final k when k.isNotEmpty) k,
  ];
}

/// Similarity of two comparison keys in [0, 1]: 1 for an exact match of
/// either the key or its alef-free skeleton, otherwise normalized edit
/// similarity (the better of key and skeleton). Very short words only
/// score highly when exact — one letter apart is a different word there.
double quranWordSimilarity(String a, String b, {QuranMatchNormalizer? n}) {
  if (a == b) return 1;
  final normalizer = n ?? const QuranMatchNormalizer();
  final sa = normalizer.skeleton(a), sb = normalizer.skeleton(b);
  if (sa == sb && sa.isNotEmpty) return 1;
  double sim(String x, String y) {
    final longest = x.length > y.length ? x.length : y.length;
    if (longest == 0) return 0;
    return 1 - _levenshtein(x, y) / longest;
  }

  var best = sim(a, b);
  if (sa.isNotEmpty && sb.isNotEmpty) {
    final skel = sim(sa, sb);
    if (skel > best) best = skel;
  }
  final shortest = a.length < b.length ? a.length : b.length;
  if (shortest <= 2) best *= 0.6;
  // Recognizers often add or drop the definite article («النار» for
  // «نارٍ»). Longer words only: «الله» must not match «له».
  final bareA = _withoutArticle(a), bareB = _withoutArticle(b);
  if ((bareA != a || bareB != b) && bareA.length >= 3 && bareA == bareB) {
    if (best < 0.85) best = 0.85;
  }
  return best;
}

String _withoutArticle(String key) =>
    key.startsWith('ال') && key.length > 4 ? key.substring(2) : key;

int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = previous[j] + 1, ins = current[j - 1] + 1;
      final sub = previous[j - 1] + cost;
      current[j] = del < ins
          ? (del < sub ? del : sub)
          : (ins < sub ? ins : sub);
    }
    final t = previous;
    previous = current;
    current = t;
  }
  return previous[b.length];
}
