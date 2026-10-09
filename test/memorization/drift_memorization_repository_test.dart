import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/data/drift_memorization_repository.dart';
import 'package:tahfeez_ai/memorization/data/memorization_database.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';

void main() {
  late MemorizationDatabase db;
  late DriftMemorizationRepository repo;
  final t0 = DateTime(2026, 10, 1, 9);

  setUp(() {
    db = MemorizationDatabase(NativeDatabase.memory());
    repo = DriftMemorizationRepository(db);
  });
  tearDown(() => db.close());

  AyahAttempt attempt(int ayah, AyahGrade grade, DateTime at) => AyahAttempt(
    ayahId: ayah,
    sessionId: 's',
    at: at,
    grade: grade,
    words: 4,
    wrong: grade == AyahGrade.fail ? 1 : 0,
    hidden: true,
  );

  test('a test is stored and each ayah\'s memory updated, in order', () async {
    await repo.recordTest([
      attempt(112001, AyahGrade.good, t0),
      attempt(112002, AyahGrade.fail, t0),
    ]);
    await repo.recordTest([
      attempt(112001, AyahGrade.good, t0.add(const Duration(days: 1))),
    ]);
    final m = await repo.watchMemories().first;
    expect(m[112001]!.stability, closeTo(2.5, 1e-6));
    expect(m[112001]!.reviews, 2);
    expect(m[112001]!.status, MemoryStatus.memorized);
    expect(m[112002]!.stability, 0.25);
    expect(m[112002]!.status, MemoryStatus.learning);
    final history = await repo.attemptsFor(112001);
    expect(history.map((a) => a.at), [t0, t0.add(const Duration(days: 1))]);
    expect((await repo.attemptsFor(112002)).single.wrong, 1);
  });

  test(
    'marking known parts: unverified, and never over what is tracked',
    () async {
      await repo.recordTest([attempt(112001, AyahGrade.good, t0)]);
      await repo.markMemorized([112001, 112002, 112003], at: t0);
      final m = await repo.watchMemories().first;
      expect(m[112001]!.verified, isTrue, reason: 'already tested: kept');
      expect(m[112002]!.verified, isFalse);
      expect(m[112002]!.stability, isNull);
      expect(m[112003]!.status, MemoryStatus.memorized);
    },
  );
}
