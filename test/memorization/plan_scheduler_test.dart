import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_plan.dart';
import 'package:tahfeez_ai/memorization/domain/plan_scheduler.dart';

void main() {
  // Juz 'Amma's end, simplified: 109-111 on page 603, 112-114 on page 604.
  final pages = <int, int>{
    for (var a = 1; a <= 6; a++) 109000 + a: 603,
    for (var a = 1; a <= 3; a++) 110000 + a: 603,
    for (var a = 1; a <= 5; a++) 111000 + a: 603,
    for (var a = 1; a <= 4; a++) 112000 + a: 604,
    for (var a = 1; a <= 5; a++) 113000 + a: 604,
    for (var a = 1; a <= 6; a++) 114000 + a: 604,
  };
  final monday = DateTime(2026, 10, 12, 18);
  final created = DateTime(2026, 10, 1);
  AyahMemory mem(int id, {DateTime? learned}) => AyahMemory(
    ayahId: id,
    status: MemoryStatus.memorized,
    stability: 3,
    lastReviewed: learned ?? monday.subtract(const Duration(days: 3)),
    learnedOn: learned ?? monday.subtract(const Duration(days: 3)),
  );
  NewLesson today(
    MemorizationPlan plan,
    Map<int, AyahMemory> memories, {
    DateTime? now,
  }) => PlanScheduler.today(
    plan: plan,
    memories: memories,
    pages: pages,
    now: now ?? monday,
  );

  test('ayahs a day, forward: the next ayahs not yet memorized', () {
    final plan = MemorizationPlan(
      fromAyah: 109001,
      toAyah: 114006,
      unit: PlanUnit.ayahs,
      amount: 3,
      createdAt: created,
    );
    expect(today(plan, {}).runs, [
      [109001, 109002, 109003],
    ]);
    final next = today(plan, {
      for (final a in [109001, 109002, 109003]) a: mem(a),
    });
    expect(next.runs, [
      [109004, 109005, 109006],
    ]);
    expect((next.memorized, next.total), (3, 29));
  });

  test(
    'backward by surah: An-Nas first, its ayahs in order, then Al-Falaq',
    () {
      final plan = MemorizationPlan(
        fromAyah: 112001,
        toAyah: 114006,
        unit: PlanUnit.ayahs,
        amount: 8,
        backward: true,
        createdAt: created,
      );
      expect(today(plan, {}).runs, [
        [114001, 114002, 114003, 114004, 114005, 114006],
        [113001, 113002],
      ]);
    },
  );

  test('a page, or half a page, a day', () {
    final pagePlan = MemorizationPlan(
      fromAyah: 109001,
      toAyah: 114006,
      createdAt: created,
    );
    expect(today(pagePlan, {}).runs.expand((r) => r), hasLength(14));
    final halves = pagePlan.copyWith(unit: PlanUnit.halfPages);
    final first = today(halves, {});
    expect(first.runs.expand((r) => r), hasLength(7), reason: 'half of 14');
    expect(first.runs.single.first, 109001);
  });

  test('learned today: the lesson is done and stays; tomorrow it moves on', () {
    final plan = MemorizationPlan(
      fromAyah: 112001,
      toAyah: 114006,
      unit: PlanUnit.ayahs,
      amount: 4,
      createdAt: created,
    );
    final memories = {
      for (final a in [112001, 112002, 112003, 112004])
        a: mem(a, learned: monday.subtract(const Duration(hours: 1))),
    };
    final done = today(plan, memories);
    expect(done.done, isTrue);
    expect(done.runs.single, [112001, 112002, 112003, 112004]);
    final tomorrow = today(
      plan,
      memories,
      now: monday.add(const Duration(days: 1)),
    );
    expect(tomorrow.done, isFalse);
    expect(tomorrow.runs.single.first, 113001);
  });

  test('half learned today: the rest of the lesson still to do', () {
    final plan = MemorizationPlan(
      fromAyah: 112001,
      toAyah: 114006,
      unit: PlanUnit.ayahs,
      amount: 4,
      createdAt: created,
    );
    final lesson = today(plan, {
      for (final a in [112001, 112002])
        a: mem(a, learned: monday.subtract(const Duration(hours: 1))),
    });
    expect(lesson.done, isFalse);
    expect(lesson.runs.single, [112001, 112002, 112003, 112004]);
  });

  test('rest days, and a finished plan', () {
    final plan = MemorizationPlan(
      fromAyah: 112001,
      toAyah: 112004,
      unit: PlanUnit.ayahs,
      daysPerWeek: 6,
      createdAt: created,
    );
    final friday = DateTime(2026, 10, 16, 9);
    expect(today(plan, {}, now: friday).rest, isTrue);
    expect(today(plan, {}).rest, isFalse);
    final all = today(plan, {
      for (var a = 1; a <= 4; a++) 112000 + a: mem(112000 + a),
    });
    expect(all.finished, isTrue);
    expect(all.progress, 1);
  });
}
