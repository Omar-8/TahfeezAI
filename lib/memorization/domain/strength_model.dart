import 'dart:math' as math;

import 'models/memorization_models.dart';

/// A small spaced-repetition model of an ayah's memory, in the spirit of
/// FSRS:
///
/// - *stability* S (days): how long after a review the ayah is still
///   recalled with 90% likelihood;
/// - *strength* R after t days: (1 + t / 9S)^-1 — 100% right after a review,
///   90% at t = S, then slowly lower;
/// - a review grows S more the more it had faded: a repeat the same day
///   (loop recitation) barely changes it, a review when due multiplies it
///   by [goodGrowth] (good) or [hardGrowth] (hard); a fail cuts it to
///   [failShrink] of itself.
///
/// The constants are a starting point, to be tuned on real use.
abstract final class StrengthModel {
  /// S after a part's first graded test.
  static const firstStability = {
    AyahGrade.good: 1.0,
    AyahGrade.hard: 0.5,
    AyahGrade.fail: 0.25,
  };

  /// S's factor for a review at 90% strength (when due).
  static const goodGrowth = 2.5, hardGrowth = 1.3;

  /// A fail: S times this, at least [minStability].
  static const failShrink = 0.3;
  static const minStability = 0.25;

  /// Below this strength a part is weak.
  static const weak = 0.7;

  /// Strength (0-1) [memory] has at [now]; `null` without a test yet.
  static double? strength(AyahMemory memory, DateTime now) {
    final s = memory.stability, last = memory.lastReviewed;
    if (s == null || last == null) return null;
    final days = math.max(0, now.difference(last).inSeconds / 86400);
    return 1 / (1 + days / (9 * s));
  }

  /// [before] (or nothing yet) after a test graded [attempt].
  static AyahMemory apply(AyahMemory? before, AyahAttempt attempt) {
    final s = before?.stability;
    final double stability;
    if (s == null) {
      stability = firstStability[attempt.grade]!;
    } else {
      final r = strength(before!, attempt.at) ?? 1;
      // Growth scaled so that a review at 90% strength gives the full factor.
      double grow(double factor) => s * (1 + (factor - 1) * (1 - r) / 0.1);
      stability = switch (attempt.grade) {
        AyahGrade.good => grow(goodGrowth),
        AyahGrade.hard => grow(hardGrowth),
        AyahGrade.fail => math.max(minStability, s * failShrink),
      };
    }
    // Memorized once recited from memory without a mistake in the words.
    final fromMemory = attempt.hidden && attempt.grade != AyahGrade.fail;
    final memorized = before?.status == MemoryStatus.memorized || fromMemory;
    return AyahMemory(
      ayahId: attempt.ayahId,
      status: memorized ? MemoryStatus.memorized : MemoryStatus.learning,
      verified: true,
      stability: stability,
      lastReviewed: attempt.at,
      // When learned in the app; a part marked as already known has none.
      learnedOn: before?.status == MemoryStatus.memorized
          ? before!.learnedOn
          : (memorized ? attempt.at : null),
      reviews: (before?.reviews ?? 0) + 1,
    );
  }
}
