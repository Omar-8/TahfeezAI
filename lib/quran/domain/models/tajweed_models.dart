import 'package:flutter/foundation.dart';

/// Tajweed colours in Ayah mode: what each colour stands for. The data's
/// eighteen rules (`assets/quran/tajweed/tajweed.json`, from
/// cpfair/quran-tajweed) grouped into ten colours, so the page stays
/// readable.
enum TajweedGroup {
  /// Written, not pronounced: hamzat al-waṣl, the lām of the sun letters,
  /// silent letters.
  unpronounced,

  /// Natural madd, 2 counts.
  maddNatural,

  /// Madd at a stop or of līn: 2, 4 or 6 counts.
  maddPermissible,

  /// Madd before a hamza (muttaṣil, munfaṣil): 4–5 counts.
  maddObligatory,

  /// Madd lāzim: 6 counts.
  maddNecessary,

  /// Ghunnah: a doubled ن / م, idghām with ghunnah, idghām shafawī.
  ghunnah,

  /// Ikhfāʾ, ikhfāʾ shafawī.
  ikhfa,

  /// Iqlāb.
  iqlab,

  /// Idghām without ghunnah (also mutajānisayn, mutaqāribayn).
  idgham,

  /// Qalqala.
  qalqala;

  /// The data's rule names, each with its colour.
  static const byRule = {
    'hamzat_wasl': unpronounced,
    'lam_shamsiyyah': unpronounced,
    'silent': unpronounced,
    'madd_2': maddNatural,
    'madd_246': maddPermissible,
    'madd_munfasil': maddObligatory,
    'madd_muttasil': maddObligatory,
    'madd_6': maddNecessary,
    'ghunnah': ghunnah,
    'idghaam_ghunnah': ghunnah,
    'idghaam_shafawi': ghunnah,
    'ikhfa': ikhfa,
    'ikhfa_shafawi': ikhfa,
    'iqlab': iqlab,
    'idghaam_no_ghunnah': idgham,
    'idghaam_mutajanisayn': idgham,
    'idghaam_mutaqaribayn': idgham,
    'qalqalah': qalqala,
  };
}

/// Code points [start]..[end] (exclusive) of one canonical word coloured
/// for [group].
@immutable
class TajweedSpan {
  const TajweedSpan(this.start, this.end, this.group);

  final int start, end;
  final TajweedGroup group;

  @override
  bool operator ==(Object other) =>
      other is TajweedSpan &&
      other.start == start &&
      other.end == end &&
      other.group == group;

  @override
  int get hashCode => Object.hash(start, end, group);

  @override
  String toString() => 'TajweedSpan($start, $end, ${group.name})';
}

/// Every word's tajweed colours, by ayah id and word index.
class TajweedIndex {
  TajweedIndex(this._ayahs, {required this.textSha256});

  /// The asset's JSON: its rule names, and per ayah a flat list of
  /// (word, start, end, rule) quadruples. Unknown rules are left out.
  factory TajweedIndex.fromJson(Map<String, Object?> json) {
    final rules = [
      for (final r in json['rules']! as List) TajweedGroup.byRule[r as String],
    ];
    final ayahs = <int, Map<int, List<TajweedSpan>>>{};
    for (final MapEntry(:key, :value)
        in (json['ayahs']! as Map<String, Object?>).entries) {
      final flat = value! as List;
      final words = ayahs[int.parse(key)] = {};
      for (var i = 0; i + 3 < flat.length; i += 4) {
        final group = rules[flat[i + 3] as int];
        if (group == null) continue;
        (words[flat[i] as int] ??= []).add(
          TajweedSpan(flat[i + 1] as int, flat[i + 2] as int, group),
        );
      }
    }
    return TajweedIndex(ayahs, textSha256: json['text_sha256']! as String);
  }

  final Map<int, Map<int, List<TajweedSpan>>> _ayahs;

  /// The canonical words it was built for (see
  /// `tool/quran_data/build_tajweed.py`).
  final String textSha256;

  /// The coloured parts of word [wordIndex] of [ayahId].
  List<TajweedSpan> spansOf(int ayahId, int wordIndex) =>
      _ayahs[ayahId]?[wordIndex] ?? const [];

  /// The ayah ids it colours.
  Iterable<int> get ayahIds => _ayahs.keys;

  /// Word [wordIndex]'s colours within a shown text made of [words] (the
  /// canonical words from [wordIndex] on, joined by single spaces — Ayah
  /// mode joins words the Mushaf joins, 15:7 «لَّوْمَا»). Spans past a
  /// word's own length are dropped (never colouring the wrong letters).
  List<TajweedSpan> spansIn(int ayahId, int wordIndex, List<String> words) {
    final out = <TajweedSpan>[];
    var offset = 0;
    for (final (i, word) in words.indexed) {
      for (final s in spansOf(ayahId, wordIndex + i)) {
        if (s.start < 0 || s.end > word.length || s.start >= s.end) continue;
        out.add(TajweedSpan(offset + s.start, offset + s.end, s.group));
      }
      offset += word.length + 1;
    }
    return out;
  }
}
