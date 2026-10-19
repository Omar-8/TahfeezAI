import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/progress_map.dart';

void main() {
  // Juz 'Amma's end, simplified: 109-111 on page 603, 112-114 on page 604;
  // and one ayah of juz 29 on page 602.
  final pages = <int, int>{
    67001: 602,
    for (var a = 1; a <= 6; a++) 109000 + a: 603,
    for (var a = 1; a <= 3; a++) 110000 + a: 603,
    for (var a = 1; a <= 5; a++) 111000 + a: 603,
    for (var a = 1; a <= 4; a++) 112000 + a: 604,
    for (var a = 1; a <= 5; a++) 113000 + a: 604,
    for (var a = 1; a <= 6; a++) 114000 + a: 604,
  };
  final juzOfAyah = {for (final a in pages.keys) a: a == 67001 ? 29 : 30};
  final now = DateTime(2026, 10, 9, 18);

  AyahMemory recited(int id, {required int daysAgo, double stability = 1}) =>
      AyahMemory(
        ayahId: id,
        status: MemoryStatus.memorized,
        verified: true,
        stability: stability,
        lastReviewed: now.subtract(Duration(days: daysAgo)),
      );
  AyahMemory marked(int id) =>
      AyahMemory(ayahId: id, status: MemoryStatus.memorized, verified: false);

  ProgressMap build(Map<int, AyahMemory> memories) => ProgressMapBuilder.build(
    memories: memories,
    pages: pages,
    juzOfAyah: juzOfAyah,
    now: now,
  );

  test('nothing memorized: every page empty, no strength, nothing weak', () {
    final map = build({});
    expect([for (final j in map.juz) j.juz], [29, 30]);
    expect([for (final p in map.juz.last.pages) p.page], [603, 604]);
    expect((map.ayahs, map.memorized, map.strength), (30, 0, null));
    expect(map.weak, isEmpty);
  });

  test('pages count their memorized ayahs; marked ones have no strength '
      'until recited', () {
    final map = build({
      for (var a = 1; a <= 4; a++) 112000 + a: recited(112000 + a, daysAgo: 0),
      114001: marked(114001),
      // Learning, not memorized: not counted.
      109001: const AyahMemory(ayahId: 109001, status: MemoryStatus.learning),
    });
    final p604 = map.juz.last.pages.last;
    expect((p604.memorized, p604.unverified, p604.strength), (5, 1, 1.0));
    expect(map.juz.last.pages.first.isEmpty, isTrue);
    expect((map.memorized, map.unverified), (5, 1));
    expect(map.share, closeTo(5 / 30, 1e-9));
  });

  test('weak pages: below the weak line, weakest first', () {
    final map = build({
      // Strength (1 + t/9S)^-1 at S=1: 9 days → 0.5; 5 days → 0.64 (weak,
      // under 0.7).
      112001: recited(112001, daysAgo: 9),
      109001: recited(109001, daysAgo: 5),
      67001: recited(67001, daysAgo: 0),
    });
    expect([for (final p in map.weak) p.page], [604, 603]);
    expect(map.weak.first.strength, closeTo(0.5, 1e-9));
    // 3 days → 0.75: fading, not weak.
    final fading = build({109001: recited(109001, daysAgo: 3)});
    expect(fading.weak, isEmpty);
  });
}
