import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_plan.dart';
import 'package:tahfeez_ai/memorization/domain/repositories/memorization_repository.dart';

/// Nothing memorized, no plan; writes are dropped. For widget tests that
/// show memorization (Home, the Memorize tab) without a database, whose
/// stream queries would leave timers pending when a test ends.
class EmptyMemorizationRepository implements MemorizationRepository {
  const EmptyMemorizationRepository();

  @override
  Future<void> recordTest(List<AyahAttempt> attempts) async {}
  @override
  Future<void> markMemorized(Iterable<int> ayahIds) async {}
  @override
  Future<void> unmarkUnverified(Iterable<int> ayahIds) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Stream<Map<int, AyahMemory>> watchMemories() => Stream.value(const {});
  @override
  Stream<List<AyahAttempt>> watchAttemptsSince(DateTime since) =>
      Stream.value(const []);
  @override
  Stream<Map<int, AyahAttempt>> watchLatestAttempts() => Stream.value(const {});
  @override
  Stream<MemorizationPlan?> watchActivePlan() => Stream.value(null);
  @override
  Future<int> savePlan(MemorizationPlan plan) async => 0;
  @override
  Future<List<AyahAttempt>> attemptsFor(int ayahId) async => const [];
}
