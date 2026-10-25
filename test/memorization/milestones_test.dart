import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/milestones.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';

AyahMemory _memorized(int ayahId, {bool verified = true}) => AyahMemory(
  ayahId: ayahId,
  status: MemoryStatus.memorized,
  verified: verified,
);

void main() {
  test('a surah and juz recited from memory, not ones only marked', () {
    final memories = {
      for (var a = 1; a <= 4; a++) 112000 + a: _memorized(112000 + a),
      for (var a = 1; a <= 5; a++)
        113000 + a: _memorized(113000 + a, verified: false),
    };
    final ids = Milestones.reached(
      memories: memories,
      juzAyahs: {
        30: [112001, 112002, 112003, 112004],
        29: [113001],
      },
      surahAyahs: {112: 4, 113: 5},
      totalAyahs: 6236,
      streak: 0,
    ).map((m) => m.id);
    expect(ids, unorderedEquals(['juz-30', 'surah-112']));
  });

  test('shares of the Quran and streaks reached', () {
    final memories = {
      for (var a = 1; a <= 63; a++) 2000 + a: _memorized(2000 + a),
    };
    final ids = Milestones.reached(
      memories: memories,
      juzAyahs: const {},
      surahAyahs: const {},
      totalAyahs: 6236,
      streak: 8,
    ).map((m) => m.id);
    expect(ids, unorderedEquals(['share-1', 'streak-3', 'streak-7']));
  });
}
