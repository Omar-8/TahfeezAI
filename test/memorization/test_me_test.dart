import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/test_me.dart';

/// "Test me": a random memorized place, its first words given.
void main() {
  final now = DateTime(2026, 10, 31);
  AyahMemory memory(
    int id, {
    MemoryStatus status = MemoryStatus.memorized,
    double? stability,
    DateTime? lastReviewed,
  }) => AyahMemory(
    ayahId: id,
    status: status,
    stability: stability,
    lastReviewed: lastReviewed,
  );

  test('nothing memorized: no question', () {
    expect(
      TestMe.pick(
        {1001: memory(1001, status: MemoryStatus.learning)},
        random: math.Random(1),
        now: now,
      ),
      isNull,
    );
  });

  test('only memorized ayahs are asked, with up to two more after it in '
      'its surah', () {
    final memories = {
      for (final id in [112001, 112002, 112003, 112004, 113001]) id: memory(id),
      114001: memory(114001, status: MemoryStatus.learning),
    };
    final seen = <int>{};
    for (var seed = 0; seed < 200; seed++) {
      final q = TestMe.pick(memories, random: math.Random(seed), now: now)!;
      seen.add(q.first);
      expect(memories[q.first]!.status, MemoryStatus.memorized);
      expect(q.last ~/ 1000, q.first ~/ 1000, reason: 'within its surah');
      expect(q.last - q.first, lessThan(TestMe.span));
      // As far as memorized ayahs go.
      expect(q.last, switch (q.first) {
        112001 => 112003,
        112002 => 112004,
        112003 => 112004,
        _ => q.first,
      });
    }
    expect(seen, {112001, 112002, 112003, 112004, 113001});
  });

  test('not the same ayah twice in a row, unless it is the only one', () {
    final two = {112001: memory(112001), 113001: memory(113001)};
    for (var seed = 0; seed < 50; seed++) {
      expect(
        TestMe.pick(
          two,
          random: math.Random(seed),
          now: now,
          not: 112001,
        )!.first,
        113001,
      );
    }
    expect(
      TestMe.pick(
        {112001: memory(112001)},
        random: math.Random(1),
        now: now,
        not: 112001,
      )!.first,
      112001,
    );
  });

  test('weaker ayahs are asked more often', () {
    final memories = {
      // Just reviewed, very stable: strength ~1, weight ~1.
      1001: memory(1001, stability: 1000, lastReviewed: now),
      // Long ago: strength ~0, weight ~3.
      2001: memory(
        2001,
        stability: 1,
        lastReviewed: now.subtract(const Duration(days: 3650)),
      ),
    };
    var weak = 0;
    final random = math.Random(7);
    for (var i = 0; i < 2000; i++) {
      if (TestMe.pick(memories, random: random, now: now)!.first == 2001) {
        weak++;
      }
    }
    expect(weak / 2000, closeTo(0.75, 0.05));
  });

  test('the words given: up to three, always some left to recite', () {
    expect(TestMe.promptWords(1), 1);
    expect(TestMe.promptWords(2), 1);
    expect(TestMe.promptWords(3), 2);
    expect(TestMe.promptWords(4), 3);
    expect(TestMe.promptWords(30), 3);
  });
}
