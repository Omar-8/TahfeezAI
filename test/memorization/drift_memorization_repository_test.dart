import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/data/drift_memorization_repository.dart';
import 'package:tahfeez_ai/memorization/data/memorization_database.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_plan.dart';

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
      attempt(112001, AyahGrade.good, t0.add(const Duration(days: 2))),
    ]);
    final m = await repo.watchMemories().first;
    expect(m[112001]!.stability, closeTo(5, 1e-6));
    expect(m[112001]!.reviews, 2);
    expect(m[112001]!.status, MemoryStatus.memorized);
    expect(m[112002]!.stability, 0.25);
    expect(m[112002]!.status, MemoryStatus.learning);
    final history = await repo.attemptsFor(112001);
    expect(history.map((a) => a.at), [t0, t0.add(const Duration(days: 2))]);
    expect((await repo.attemptsFor(112002)).single.wrong, 1);
  });

  test(
    'marking known parts: unverified, and never over what is tracked',
    () async {
      await repo.recordTest([attempt(112001, AyahGrade.good, t0)]);
      await repo.markMemorized([112001, 112002, 112003]);
      final m = await repo.watchMemories().first;
      expect(m[112001]!.verified, isTrue, reason: 'already tested: kept');
      expect(m[112002]!.verified, isFalse);
      expect(m[112002]!.stability, isNull);
      expect(m[112003]!.status, MemoryStatus.memorized);
      expect(m[112003]!.learnedOn, isNull, reason: 'not learned in the app');
    },
  );

  test('clearing all: no memories, results or plans left', () async {
    await repo.recordTest([attempt(112001, AyahGrade.good, t0)]);
    await repo.markMemorized([112002]);
    await repo.savePlan(
      MemorizationPlan(fromAyah: 78001, toAyah: 114006, createdAt: t0),
    );
    await repo.clearAll();
    expect(await repo.watchMemories().first, isEmpty);
    expect(await repo.attemptsFor(112001), isEmpty);
    expect(await repo.watchActivePlan().first, isNull);
  });

  test('unmarking removes only what is still unverified', () async {
    await repo.recordTest([attempt(112001, AyahGrade.good, t0)]);
    await repo.markMemorized([112001, 112002, 112003]);
    await repo.unmarkUnverified([112001, 112002]);
    final m = await repo.watchMemories().first;
    expect(m.keys.toSet(), {112001, 112003});
  });

  test('ayahs recited each day, by local date', () async {
    await repo.recordTest([
      attempt(112001, AyahGrade.good, t0),
      attempt(112002, AyahGrade.good, t0.add(const Duration(hours: 14))),
      attempt(112003, AyahGrade.fail, t0.add(const Duration(days: 2))),
    ]);
    expect(await repo.watchDailyRecited().first, {
      DateTime(2026, 10, 1): 2,
      DateTime(2026, 10, 3): 1,
    });
  });

  test('each ayah\'s latest result', () async {
    await repo.recordTest([
      attempt(112001, AyahGrade.fail, t0),
      attempt(112002, AyahGrade.good, t0),
    ]);
    await repo.recordTest([
      attempt(112001, AyahGrade.good, t0.add(const Duration(hours: 1))),
    ]);
    final latest = await repo.watchLatestAttempts().first;
    expect(latest.keys.toSet(), {112001, 112002});
    expect(latest[112001]!.grade, AyahGrade.good);
    expect(latest[112001]!.at, t0.add(const Duration(hours: 1)));
  });

  test('plans: one active at a time, updated in place', () async {
    expect(await repo.watchActivePlan().first, isNull);
    final first = await repo.savePlan(
      MemorizationPlan(fromAyah: 78001, toAyah: 114006, createdAt: t0),
    );
    var active = await repo.watchActivePlan().first;
    expect(
      (active!.id, active.unit, active.amount),
      (first, PlanUnit.pages, 1),
    );
    await repo.savePlan(
      active.copyWith(
        amount: 2,
        unit: PlanUnit.halfPages,
        studyDays: {DateTime.monday, DateTime.thursday},
      ),
    );
    active = await repo.watchActivePlan().first;
    expect(
      (active!.id, active.unit, active.amount),
      (first, PlanUnit.halfPages, 2),
    );
    expect(active.studyDays, {DateTime.monday, DateTime.thursday});
    // A new active plan replaces it; pausing leaves none.
    final second = await repo.savePlan(
      MemorizationPlan(
        fromAyah: 1001,
        toAyah: 2286,
        backward: true,
        createdAt: t0,
      ),
    );
    active = await repo.watchActivePlan().first;
    expect((active!.id, active.backward), (second, true));
    await repo.savePlan(active.copyWith(active: false));
    expect(await repo.watchActivePlan().first, isNull);
  });

  test('schema 1 plans: their day count becomes weekdays', () async {
    await db.close();
    db = MemorizationDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, from_ayah INTEGER NOT NULL, '
            'to_ayah INTEGER NOT NULL, unit TEXT NOT NULL, '
            'amount REAL NOT NULL, days_per_week INTEGER NOT NULL, '
            'backward INTEGER NOT NULL, active INTEGER NOT NULL, '
            'created_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO plans VALUES (1, '', 78001, 114006, 'pages', 1, 5, "
            '1, 1, 0)',
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    repo = DriftMemorizationRepository(db);
    final plan = await repo.watchActivePlan().first;
    expect(plan!.studyDays, {1, 2, 3, 6, 7}, reason: 'Thursday, Friday off');
  });
}
