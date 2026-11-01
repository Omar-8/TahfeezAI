import 'dart:math' as math;

import '../../quran/domain/quran_ayah_numbers.dart' show surahAyahCounts;
import 'models/memorization_models.dart';
import 'strength_model.dart';

/// "Test me": as a teacher does, a random place in what is memorized — its
/// first words read out, the rest recited from memory.
class TestMeQuestion {
  const TestMeQuestion({required this.first, required this.last});

  /// The ayah whose opening words are given (stable id).
  final int first;

  /// The last ayah to recite: up to [TestMe.span] memorized ayahs from
  /// [first] — on into the next surah when that is memorized too (as a
  /// teacher would let Al-Ikhlas run on into Al-Falaq).
  final int last;

  @override
  bool operator ==(Object other) =>
      other is TestMeQuestion && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}

abstract final class TestMe {
  /// Ayahs recited in one question (the given one included).
  static const span = 3;

  /// The opening words given for an ayah of [words] words: up to three,
  /// always leaving some to recite — a one-word ayah (الٓمٓ) is given
  /// whole, its next ayah recited.
  static int promptWords(int words) =>
      words <= 1 ? words : math.min(3, words - 1);

  static bool isMemorized(Map<int, AyahMemory> memories, int ayahId) =>
      memories[ayahId]?.status == MemoryStatus.memorized;

  /// A question from the [memories]' memorized ayahs; weaker ones are
  /// asked more often (weight 1 + 2 × (1 − strength); unverified or never
  /// tested: 2). [not]: the last question's ayah, not asked twice in a row
  /// (unless it is the only one). `null` when nothing is memorized.
  static TestMeQuestion? pick(
    Map<int, AyahMemory> memories, {
    required math.Random random,
    required DateTime now,
    int? not,
  }) {
    bool memorized(int id) => isMemorized(memories, id);
    final ids = [
      for (final m in memories.values)
        if (m.status == MemoryStatus.memorized) m.ayahId,
    ]..sort();
    if (ids.isEmpty) return null;
    final pool = ids.length > 1 ? ids.where((id) => id != not).toList() : ids;
    final weights = [
      for (final id in pool)
        switch (StrengthModel.strength(memories[id]!, now)) {
          final s? => 1 + 2 * (1 - s.clamp(0, 1)),
          null => 2.0,
        },
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var at = random.nextDouble() * total;
    var first = pool.last;
    for (final (i, w) in weights.indexed) {
      if (at < w) {
        first = pool[i];
        break;
      }
      at -= w;
    }
    // The next memorized ayahs, across a surah's end (stable ids are
    // surah × 1000 + ayah).
    int? after(int id) {
      final surah = id ~/ 1000;
      if (id % 1000 < surahAyahCounts[surah - 1]) return id + 1;
      return surah < 114 ? (surah + 1) * 1000 + 1 : null;
    }

    var last = first;
    for (var n = 1; n < span; n++) {
      final next = after(last);
      if (next == null || !memorized(next)) break;
      last = next;
    }
    return TestMeQuestion(first: first, last: last);
  }
}
