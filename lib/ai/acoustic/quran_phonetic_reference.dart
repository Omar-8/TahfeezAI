import '../../quran/domain/models/quran_refs.dart';

/// The Quran Phonetic Script symbols the acoustic models use, in class
/// order (index 0 is the CTC blank).
const quranPhoneticVocabulary = <String>[
  '', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', //
  'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', //
  'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ', 'َ', //
  'ُ', 'ِ', '۪', 'ـ', 'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ',
];

const ctcBlank = 0;

final Map<String, int> _classOf = {
  for (var i = 1; i < quranPhoneticVocabulary.length; i++)
    quranPhoneticVocabulary[i]: i,
};

int phoneticClassOf(String symbol) => _classOf[symbol]!;

/// [symbol]'s class, or `null` if it has none.
int? phoneticClassOrNull(String symbol) => _classOf[symbol];

/// The three short vowels.
enum ShortVowel {
  fatha('َ'),
  damma('ُ'),
  kasra('ِ');

  const ShortVowel(this.symbol);
  final String symbol;

  int get token => phoneticClassOf(symbol);

  static ShortVowel? ofToken(int token) {
    for (final v in values) {
      if (v.token == token) return v;
    }
    return null;
  }
}

/// The consonants a letter may be mistaken for.
final List<int> consonantTokens = [
  for (final c in 'ءبتثجحخدذرزسشصضطظعغفقكلمنهوي'.split('')) phoneticClassOf(c),
];

enum PhoneticTokenKind {
  /// A short vowel.
  vowel,

  /// A long vowel or a nasal (ghunna): its length is not judged.
  long,
  consonant,

  /// A tajweed marker (qalqala, sakt): may be absent.
  marker,
}

/// One expected CTC token of an ayah's pronunciation, mapped back to the
/// Quran text.
class PhoneticToken {
  const PhoneticToken({
    required this.token,
    required this.kind,
    required this.unit,
    required this.word,
    required this.letter,
    required this.sourceChar,
    this.geminate = false,
    this.unitFinalVowel = false,
    this.count = 1,
  });

  /// Its length in harakat where it has one: a madd (long vowel) or a
  /// ghunnah (geminate nasal); 1 otherwise.
  final int count;

  /// Class in [quranPhoneticVocabulary].
  final int token;
  final PhoneticTokenKind kind;

  /// Sound unit within the ayah (words pronounced as one share a unit).
  final int unit;

  /// The word it belongs to.
  final WordRef word;

  /// Which base letter of that word (0-based) it comes from.
  final int letter;

  /// The Uthmani character it comes from (a letter or a mark).
  final String sourceChar;

  /// The second copy of a doubled consonant (shadda).
  final bool geminate;

  /// A short vowel closing a sound unit — dropped at a pause (waqf).
  final bool unitFinalVowel;

  String get symbol => quranPhoneticVocabulary[token];

  bool get optional => kind == PhoneticTokenKind.marker;

  /// The same token, in sound unit [unit] (units renumbered when ayahs
  /// are joined into one sequence).
  PhoneticToken withUnit(int unit) => PhoneticToken(
    token: token,
    kind: kind,
    unit: unit,
    word: word,
    letter: letter,
    sourceChar: sourceChar,
    geminate: geminate,
    unitFinalVowel: unitFinalVowel,
    count: count,
  );
}

/// The expected pronunciation of a run of words, possibly across ayahs:
/// tokens with sound units numbered through the whole run, and those
/// units' pause forms.
class PhoneticSpan {
  const PhoneticSpan(this.tokens, this.pauses);
  final List<PhoneticToken> tokens;
  final Map<int, PauseForms> pauses;
}

/// A sound unit's pronunciation when the reciter pauses around it: stops
/// after it (waqf) — tanween dropped, ta marbuta as ه, a final vowel
/// silent — or starts with it (ibtida) — hamzat al-wasl pronounced. An
/// ayah's last unit, whose default is its waqf form, may instead continue
/// into the next ayah ([wasl]); its first unit, by default as started
/// afresh, may be joined on from the previous ayah ([joined]).
class PauseForms {
  const PauseForms({
    this.waqf,
    this.ibtida,
    this.wasl,
    this.joined,
    this.splits = const {},
  });

  /// (tokens dropped from the unit's end, tokens put there instead).
  final (int, List<PhoneticToken>)? waqf;

  /// (tokens dropped from the unit's start, tokens put there instead).
  final (int, List<PhoneticToken>)? ibtida;

  /// An ayah's last unit said on into the next ayah (an end edit).
  final (int, List<PhoneticToken>)? wasl;

  /// An ayah's first unit said on from the previous ayah (a start edit).
  final (int, List<PhoneticToken>)? joined;

  /// A unit of several words (joined in flow, e.g. by idgham across a word
  /// boundary) as said when the reciter stops inside it, after word k (its
  /// index in the ayah): the whole unit — the words up to k at a stop, the
  /// rest started afresh.
  final Map<int, List<PhoneticToken>> splits;

  PauseForms withUnit(int unit) {
    (int, List<PhoneticToken>)? move((int, List<PhoneticToken>)? f) =>
        f == null ? null : (f.$1, [for (final t in f.$2) t.withUnit(unit)]);
    return PauseForms(
      waqf: move(waqf),
      ibtida: move(ibtida),
      wasl: move(wasl),
      joined: move(joined),
      splits: {
        for (final MapEntry(:key, :value) in splits.entries)
          key: [for (final t in value) t.withUnit(unit)],
      },
    );
  }

  /// [unit] (its default tokens) as said after / before a pause.
  /// [end] / [begin] false leave that side of the unit as it is.
  List<PhoneticToken> apply(
    List<PhoneticToken> unit, {
    required bool stop,
    required bool start,
    bool end = true,
    bool begin = true,
  }) {
    var out = unit;
    final endEdit = end ? (stop ? waqf : wasl) : null;
    if (endEdit != null) {
      out = [...out.sublist(0, out.length - endEdit.$1), ...endEdit.$2];
    }
    final beginEdit = begin ? (start ? ibtida : joined) : null;
    if (beginEdit != null) {
      out = [...beginEdit.$2, ...out.sublist(beginEdit.$1)];
    }
    return out;
  }
}

/// The expected pronunciation of every ayah (Hafs), from
/// `assets/quran/recitation/phonetic_reference_hafs.json` — built from the
/// canonical text by `tool/acoustic_verification/build_reference.py`, with
/// word counts and letters checked against Tahfeez's dataset.
class QuranPhoneticReference {
  QuranPhoneticReference(this._ayahs);

  factory QuranPhoneticReference.fromJson(Map<String, Object?> json) {
    if (json['format'] != 3) {
      throw const FormatException('Unknown phonetic reference format');
    }
    final raw = (json['ayahs']! as Map).cast<String, Object?>();
    return QuranPhoneticReference({
      for (final MapEntry(:key, :value) in raw.entries)
        int.parse(key): (value! as Map).cast<String, Object?>(),
    });
  }

  final Map<int, Map<String, Object?>> _ayahs;
  final _cache = <int, List<PhoneticToken>>{};
  final _pauseCache = <int, Map<int, PauseForms>>{};

  bool hasAyah(int ayahId) => _ayahs.containsKey(ayahId);

  /// The expected tokens of an ayah, in order.
  List<PhoneticToken> ayah(int ayahId) => _cache[ayahId] ??= _decode(ayahId);

  /// Every ayah's id.
  Iterable<int> get ayahIds => _ayahs.keys;

  /// An ayah's token classes and the word index of each, leaving out
  /// optional markers — without building [PhoneticToken]s (for indexing
  /// the whole Quran).
  ({List<int> classes, List<int> words})? encoded(int ayahId) {
    final row = _ayahs[ayahId];
    if (row == null) return null;
    final t = (row['t']! as String).runes.toList();
    final w = (row['w']! as String).runes.toList();
    final f = (row['f']! as String).runes.toList();
    final classes = <int>[], words = <int>[];
    for (var i = 0; i < t.length; i++) {
      if ((f[i] - 64) & 8 != 0) continue; // marker
      classes.add(phoneticClassOf(String.fromCharCode(t[i])));
      words.add(w[i] - 48);
    }
    return (classes: classes, words: words);
  }

  /// The expected tokens of words [first]..[last] of one ayah (inclusive),
  /// whole sound units only.
  List<PhoneticToken> words(int ayahId, int first, int last) {
    final all = ayah(ayahId);
    final units = {
      for (final t in all)
        if (t.word.wordIndex >= first && t.word.wordIndex <= last) t.unit,
    };
    return [
      for (final t in all)
        if (units.contains(t.unit)) t,
    ];
  }

  /// The expected pronunciation of [words] (in reading order, whole sound
  /// units), joined across ayahs.
  PhoneticSpan span(List<WordRef> words) {
    final byAyah = <int, List<int>>{};
    for (final w in words) {
      (byAyah[w.ayahId] ??= []).add(w.wordIndex);
    }
    final tokens = <PhoneticToken>[];
    final pauses = <int, PauseForms>{};
    var offset = 0;
    for (final MapEntry(key: ayahId, value: indices) in byAyah.entries) {
      final part = this.words(
        ayahId,
        indices.reduce((a, b) => a < b ? a : b),
        indices.reduce((a, b) => a > b ? a : b),
      );
      if (part.isEmpty) continue;
      final forms = pauseForms(ayahId);
      final first = part.first.unit;
      for (final t in part) {
        tokens.add(t.withUnit(offset + t.unit - first));
      }
      for (final u in {for (final t in part) t.unit}) {
        final f = forms[u];
        if (f != null) {
          pauses[offset + u - first] = f.withUnit(offset + u - first);
        }
      }
      offset += part.last.unit - first + 1;
    }
    return PhoneticSpan(tokens, pauses);
  }

  /// Per sound unit (that has any), its forms at a pause.
  Map<int, PauseForms> pauseForms(int ayahId) =>
      _pauseCache[ayahId] ??= _decodePauses(ayahId);

  Map<int, PauseForms> _decodePauses(int ayahId) {
    final raw = (_ayahs[ayahId]?['v'] as Map?)?.cast<String, Object?>();
    if (raw == null) return const {};
    (int, List<PhoneticToken>)? form(Object? v, int unit) {
      if (v == null) return null;
      final l = (v as List);
      return (
        l[0] as int,
        _tokens(ayahId, [
          for (var i = 1; i < 6; i++) l[i] as String,
        ], unit: unit),
      );
    }

    return {
      for (final MapEntry(:key, :value) in raw.entries)
        int.parse(key): () {
          final m = (value! as Map).cast<String, Object?>();
          final unit = int.parse(key);
          return PauseForms(
            waqf: form(m['w'], unit),
            ibtida: form(m['i'], unit),
            wasl: form(m['c'], unit),
            joined: form(m['j'], unit),
            splits: {
              for (final MapEntry(:key, :value)
                  in ((m['s'] as Map?) ?? const {}).entries)
                int.parse(key as String): form(value, unit)!.$2,
            },
          );
        }(),
    };
  }

  List<PhoneticToken> _decode(int ayahId) {
    final row = _ayahs[ayahId];
    if (row == null) return const [];
    return _tokens(
      ayahId,
      [
        for (final k in const ['t', 'w', 'l', 'c', 'f']) row[k]! as String,
      ],
      units: row['u']! as String,
      counts: row['n'] as String?,
    );
  }

  /// Tokens from their encoded fields (t, w, l, c, f); the unit of each
  /// from [units], or [unit] for all.
  List<PhoneticToken> _tokens(
    int ayahId,
    List<String> fields, {
    String? units,
    int unit = 0,
    String? counts,
  }) {
    final t = fields[0].runes.toList();
    final w = fields[1].runes.toList();
    final l = fields[2].runes.toList();
    final c = fields[3].runes.toList();
    final f = fields[4].runes.toList();
    final u = units?.runes.toList();
    final n = counts?.runes.toList();
    return [
      for (var i = 0; i < t.length; i++)
        () {
          final flags = f[i] - 64;
          return PhoneticToken(
            token: phoneticClassOf(String.fromCharCode(t[i])),
            kind: flags & 1 != 0
                ? PhoneticTokenKind.vowel
                : flags & 2 != 0
                ? PhoneticTokenKind.long
                : flags & 8 != 0
                ? PhoneticTokenKind.marker
                : PhoneticTokenKind.consonant,
            unit: u == null ? unit : u[i] - 48,
            word: (ayahId: ayahId, wordIndex: w[i] - 48),
            letter: l[i] - 48,
            sourceChar: String.fromCharCode(c[i]),
            geminate: flags & 16 != 0,
            unitFinalVowel: flags & 32 != 0,
            count: n == null ? 1 : n[i] - 48,
          );
        }(),
    ];
  }
}
