/// Ayahs that look alike (mutashābihāt): which other ayahs an ayah is
/// easily mixed up with, and the words in which they differ — computed
/// from the app's own Quran text (`tool/quran_data/build_similar_ayahs.py`).
/// Holds only ayah ids and word positions; the words are shown from the
/// canonical text.
library;

/// One ayah similar to another: [ayahId], how alike they are ([score],
/// 0–100: the share of their words the same, in order), and which of its
/// words ([differ], word indexes) and of the other's ([otherDiffer]) are
/// not shared.
class SimilarAyah {
  const SimilarAyah({
    required this.ayahId,
    required this.score,
    required this.differ,
    required this.otherDiffer,
  });

  final int ayahId;
  final int score;
  final Set<int> differ;
  final Set<int> otherDiffer;

  /// Word for word the same as the other.
  bool get identical => differ.isEmpty && otherDiffer.isEmpty;
}

class SimilarAyahs {
  SimilarAyahs._(this._byAyah);

  /// Reads the bundled file's JSON (its `pairs`).
  factory SimilarAyahs.fromJson(Map<String, Object?> json) {
    final byAyah = <int, List<SimilarAyah>>{};
    Set<int> indexes(Object? s) => {
      for (final part in (s as String).split(','))
        if (part.isNotEmpty) int.parse(part),
    };
    for (final raw in json['pairs'] as List<Object?>) {
      final p = raw as List<Object?>;
      final a = p[0] as int, b = p[1] as int, score = p[2] as int;
      final da = indexes(p[3]), db = indexes(p[4]);
      (byAyah[a] ??= []).add(
        SimilarAyah(ayahId: b, score: score, differ: db, otherDiffer: da),
      );
      (byAyah[b] ??= []).add(
        SimilarAyah(ayahId: a, score: score, differ: da, otherDiffer: db),
      );
    }
    for (final list in byAyah.values) {
      // The most alike first; then in the Quran's order.
      list.sort(
        (x, y) => x.score != y.score
            ? y.score.compareTo(x.score)
            : x.ayahId.compareTo(y.ayahId),
      );
    }
    return SimilarAyahs._(byAyah);
  }

  final Map<int, List<SimilarAyah>> _byAyah;

  /// The ayahs like [ayahId], the most alike first; empty if none.
  List<SimilarAyah> of(int ayahId) => _byAyah[ayahId] ?? const [];

  /// How many ayahs have a look-alike.
  int get ayahCount => _byAyah.length;
}
