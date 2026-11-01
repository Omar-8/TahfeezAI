import 'dart:math' as math;

import 'models/memorization_models.dart';
import 'strength_model.dart';

/// "Test me": as a teacher does, a random place in what is memorized — its
/// first words read out, the rest recited from memory.
class TestMeQuestion {
  const TestMeQuestion({required this.first, required this.last});

  /// The ayah whose opening words are given (stable id).
  final int first;

  /// The last ayah to recite: up to [TestMe.span] memorized ayahs from
  /// [first], within its surah.
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
    // The next memorized ayahs of its surah (stable ids are surah × 1000 +
    // ayah, consecutive within a surah).
    var last = first;
    while (last - first < span - 1 && memorized(last + 1)) {
      last++;
    }
    return TestMeQuestion(first: first, last: last);
  }
}
