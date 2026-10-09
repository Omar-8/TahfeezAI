import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/today_scheduler.dart';

void main() {
  final now = DateTime(2026, 10, 20, 18);
  // Juz 'Amma's last pages, simplified: 112 on 604, 113 on 604, 111 on 603,
  // 110 on 603, 109 on 603.
  final pages = <int, int>{
    for (var a = 1; a <= 6; a++) 109000 + a: 603,
    for (var a = 1; a <= 3; a++) 110000 + a: 603,
    for (var a = 1; a <= 5; a++) 111000 + a: 603,
    for (var a = 1; a <= 4; a++) 112000 + a: 604,
    for (var a = 1; a <= 5; a++) 113000 + a: 604,
    for (var a = 1; a <= 6; a++) 114000 + a: 604,
  };
  AyahMemory mem(
    int id, {
    MemoryStatus status = MemoryStatus.memorized,
    double? stability = 5,
    int reviewedDaysAgo = 3,
    int? learnedDaysAgo = 60,
    bool verified = true,
  }) => AyahMemory(
    ayahId: id,
    status: status,
    verified: verified,
    stability: stability,
    lastReviewed: stability == null
        ? null
        : now.subtract(Duration(days: reviewedDaysAgo)),
    learnedOn: learnedDaysAgo == null
        ? null
        : now.subtract(Duration(days: learnedDaysAgo)),
  );

  test('nothing memorized: an empty day', () {
    expect(
      TodayScheduler.plan(memories: {}, pages: pages, now: now).isEmpty,
      isTrue,
    );
  });

  test('recent revision: what is being learned or learned this week, as '
      'consecutive runs', () {
    final plan = TodayScheduler.plan(
      memories: {
        for (final a in [112001, 112002, 112003, 112004])
          a: mem(a, learnedDaysAgo: 2),
        113001: mem(
          113001,
          status: MemoryStatus.learning,
          learnedDaysAgo: null,
        ),
        // A gap, then another run.
        114005: mem(114005, learnedDaysAgo: 1),
        114006: mem(114006, learnedDaysAgo: 1),
        // Learned long ago: old revision.
        109001: mem(109001),
      },
      pages: pages,
      now: now,
    );
    expect(
      [for (final t in plan.recent) (t.first, t.last)],
      [(112001, 113001), (114005, 114006)],
    );
    expect(plan.old.map((t) => t.page), [603]);
  });

  test('old revision: by page, unverified first, then the weakest', () {
    final plan = TodayScheduler.plan(
      memories: {
        // Page 603: strong.
        for (var a = 1; a <= 6; a++)
          109000 + a: mem(109000 + a, stability: 30, reviewedDaysAgo: 2),
        // Page 604: weak (reviewed long ago for its stability).
        for (var a = 1; a <= 4; a++)
          112000 + a: mem(112000 + a, stability: 1, reviewedDaysAgo: 20),
      },
      pages: pages,
      now: now,
    );
    expect(plan.old.map((t) => t.page), [604, 603]);
    expect(plan.old.first.strength!, lessThan(0.5));
    expect(plan.old.last.strength!, greaterThan(0.9));

    final withMarked = TodayScheduler.plan(
      memories: {
        for (var a = 1; a <= 4; a++)
          112000 + a: mem(112000 + a, stability: 1, reviewedDaysAgo: 20),
        // Marked as known, never recited: first.
        for (var a = 1; a <= 5; a++)
          111000 + a: mem(
            111000 + a,
            stability: null,
            verified: false,
            learnedDaysAgo: null,
          ),
      },
      pages: pages,
      now: now,
    );
    expect(withMarked.old.first.page, 603);
    expect(withMarked.old.first.unverified, isTrue);
    expect(withMarked.old.first.strength, isNull);
  });

  test('a page reviewed today stays on the list, done', () {
    final plan = TodayScheduler.plan(
      memories: {
        for (var a = 1; a <= 4; a++)
          112000 + a: mem(112000 + a, reviewedDaysAgo: 0),
      },
      pages: pages,
      now: now,
    );
    expect(plan.old.single.done, isTrue);
  });
}
