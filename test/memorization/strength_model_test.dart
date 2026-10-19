import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/strength_model.dart';

void main() {
  final t0 = DateTime(2026, 10, 1, 9);
  AyahAttempt attempt(AyahGrade grade, DateTime at, {bool hidden = true}) =>
      AyahAttempt(
        ayahId: 112001,
        sessionId: 's',
        at: at,
        grade: grade,
        words: 4,
        hidden: hidden,
      );

  test('a first test sets the stability by its grade', () {
    for (final (grade, s) in [
      (AyahGrade.good, 2.0),
      (AyahGrade.hard, 1.0),
      (AyahGrade.fail, 0.25),
    ]) {
      final m = StrengthModel.apply(null, attempt(grade, t0));
      expect(m.stability, s, reason: grade.name);
      expect(m.reviews, 1);
      expect(m.verified, isTrue);
    }
  });

  test('strength: 100% right after a review, 90% when due, then lower', () {
    final m = StrengthModel.apply(null, attempt(AyahGrade.good, t0));
    expect(StrengthModel.strength(m, t0), 1);
    expect(
      StrengthModel.strength(m, t0.add(const Duration(days: 2))),
      closeTo(0.9, 1e-9),
    );
    expect(
      StrengthModel.strength(m, t0.add(const Duration(days: 7))),
      greaterThan(StrengthModel.weak),
    );
    expect(
      StrengthModel.strength(m, t0.add(const Duration(days: 8))),
      lessThan(StrengthModel.weak),
    );
  });

  test('a review when due multiplies the stability; a repeat the same day '
      'barely changes it', () {
    final m = StrengthModel.apply(null, attempt(AyahGrade.good, t0));
    final due = t0.add(const Duration(days: 2));
    expect(
      StrengthModel.apply(m, attempt(AyahGrade.good, due)).stability,
      closeTo(5, 1e-6),
    );
    expect(
      StrengthModel.apply(m, attempt(AyahGrade.hard, due)).stability,
      closeTo(2.6, 1e-6),
    );
    final again = StrengthModel.apply(
      m,
      attempt(AyahGrade.good, t0.add(const Duration(minutes: 2))),
    );
    expect(again.stability, closeTo(2.0, 0.01), reason: 'loop: no cramming');
  });

  test('a fail cuts the stability, never below the minimum', () {
    var m = StrengthModel.apply(null, attempt(AyahGrade.good, t0));
    m = m.copyWith(stability: 10);
    final failed = StrengthModel.apply(
      m,
      attempt(AyahGrade.fail, t0.add(const Duration(days: 5))),
    );
    expect(failed.stability, closeTo(3, 1e-9));
    final low = StrengthModel.apply(
      failed.copyWith(stability: 0.5),
      attempt(AyahGrade.fail, t0.add(const Duration(days: 6))),
    );
    expect(low.stability, StrengthModel.minStability);
  });

  test('memorized once recited from memory without a mistake in the words', () {
    final seen = StrengthModel.apply(
      null,
      attempt(AyahGrade.good, t0, hidden: false),
    );
    expect(seen.status, MemoryStatus.learning, reason: 'read, not recalled');
    final failed = StrengthModel.apply(seen, attempt(AyahGrade.fail, t0));
    expect(failed.status, MemoryStatus.learning);
    final recalled = StrengthModel.apply(failed, attempt(AyahGrade.hard, t0));
    expect(recalled.status, MemoryStatus.memorized);
    expect(recalled.learnedOn, t0);
    final later = StrengthModel.apply(
      recalled,
      attempt(AyahGrade.fail, t0.add(const Duration(days: 3))),
    );
    expect(later.status, MemoryStatus.memorized, reason: 'stays memorized');
    expect(later.learnedOn, t0);
  });

  test('a part marked as known is verified by its first test', () {
    const marked = AyahMemory(
      ayahId: 112001,
      status: MemoryStatus.memorized,
      verified: false,
    );
    expect(StrengthModel.strength(marked, t0), isNull);
    final tested = StrengthModel.apply(marked, attempt(AyahGrade.good, t0));
    expect(tested.verified, isTrue);
    expect(tested.stability, 2.0);
    expect(tested.status, MemoryStatus.memorized);
    expect(tested.learnedOn, isNull, reason: 'known before, not learned now');
  });
}
