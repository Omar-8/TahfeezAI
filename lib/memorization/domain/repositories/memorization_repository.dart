import '../models/memorization_models.dart';

/// Read/write access to Tahfeez's core differentiator: what the user has
/// memorized, how strong each ayah is, and every test's per-ayah results.
///
/// Mutable user data, kept entirely on the device and separate from the
/// immutable Quran data (`docs/MEMORIZATION_MILESTONE.md`).
abstract class MemorizationRepository {
  /// Stores a test's graded ayahs and updates each one's memory
  /// (`StrengthModel.apply`), in order.
  Future<void> recordTest(List<AyahAttempt> attempts);

  /// Marks ayahs the user already knows as memorized, unverified (no
  /// strength) until first recited. Ayahs already tracked are left as they
  /// are.
  Future<void> markMemorized(Iterable<int> ayahIds);

  /// The memory of every tracked ayah, by ayah id, updated as it changes.
  Stream<Map<int, AyahMemory>> watchMemories();

  /// Every test result from [since] on, oldest first, updated as tests are
  /// recorded.
  Stream<List<AyahAttempt>> watchAttemptsSince(DateTime since);

  /// Each ayah's latest test result, by ayah id, updated as tests are
  /// recorded.
  Stream<Map<int, AyahAttempt>> watchLatestAttempts();

  /// [ayahId]'s test results, oldest first.
  Future<List<AyahAttempt>> attemptsFor(int ayahId);
}
