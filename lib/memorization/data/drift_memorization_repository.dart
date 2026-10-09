import 'package:drift/drift.dart';

import '../domain/models/memorization_models.dart';
import '../domain/models/memorization_plan.dart';
import '../domain/repositories/memorization_repository.dart';
import '../domain/strength_model.dart';
import 'memorization_database.dart';

/// [MemorizationRepository] on the memorization database.
class DriftMemorizationRepository implements MemorizationRepository {
  DriftMemorizationRepository(this._db);

  final MemorizationDatabase _db;

  @override
  Future<void> recordTest(List<AyahAttempt> attempts) async {
    if (attempts.isEmpty) return;
    await _db.transaction(() async {
      final ids = {for (final a in attempts) a.ayahId};
      final rows = await (_db.select(
        _db.memorizedAyahs,
      )..where((t) => t.ayahId.isIn(ids))).get();
      final memories = {for (final r in rows) r.ayahId: _memory(r)};
      for (final a in attempts) {
        await _db
            .into(_db.attempts)
            .insert(
              AttemptsCompanion.insert(
                sessionId: a.sessionId,
                ayahId: a.ayahId,
                at: a.at,
                grade: a.grade.name,
                words: a.words,
                wrong: a.wrong,
                skipped: a.skipped,
                selfCorrected: a.selfCorrected,
                pronunciation: a.pronunciation,
                hidden: a.hidden,
              ),
            );
        memories[a.ayahId] = StrengthModel.apply(memories[a.ayahId], a);
      }
      for (final m in memories.values.where((m) => ids.contains(m.ayahId))) {
        await _db.into(_db.memorizedAyahs).insertOnConflictUpdate(_row(m));
      }
    });
  }

  @override
  Future<void> markMemorized(Iterable<int> ayahIds) async {
    await _db.batch((b) {
      b.insertAll(_db.memorizedAyahs, [
        for (final id in ayahIds)
          MemorizedAyahsCompanion.insert(
            ayahId: Value(id),
            status: MemoryStatus.memorized.name,
            verified: false,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<void> unmarkUnverified(Iterable<int> ayahIds) =>
      (_db.delete(_db.memorizedAyahs)..where(
            (t) => t.ayahId.isIn(ayahIds.toList()) & t.verified.equals(false),
          ))
          .go();

  @override
  Future<void> clearAll() => _db.transaction(() async {
    await _db.delete(_db.attempts).go();
    await _db.delete(_db.memorizedAyahs).go();
    await _db.delete(_db.plans).go();
  });

  @override
  Stream<Map<int, AyahMemory>> watchMemories() => _db
      .select(_db.memorizedAyahs)
      .watch()
      .map((rows) => {for (final r in rows) r.ayahId: _memory(r)});

  @override
  Stream<List<AyahAttempt>> watchAttemptsSince(DateTime since) =>
      (_db.select(_db.attempts)
            ..where((t) => t.at.isBiggerOrEqualValue(since))
            ..orderBy([(t) => OrderingTerm.asc(t.at)]))
          .watch()
          .map((rows) => [for (final r in rows) _attempt(r)]);

  @override
  Stream<Map<int, AyahAttempt>> watchLatestAttempts() => _db
      .customSelect(
        'SELECT a.* FROM attempts a JOIN (SELECT ayah_id, MAX(id) AS last '
        'FROM attempts GROUP BY ayah_id) l ON a.id = l.last',
        readsFrom: {_db.attempts},
      )
      .watch()
      .asyncMap(
        (rows) async => {
          for (final r in rows)
            r.read<int>('ayah_id'): _attempt(await _db.attempts.mapFromRow(r)),
        },
      );

  @override
  Stream<MemorizationPlan?> watchActivePlan() =>
      (_db.select(_db.plans)
            ..where((t) => t.active.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _plan(r));

  @override
  Future<int> savePlan(MemorizationPlan plan) => _db.transaction(() async {
    if (plan.active) {
      await (_db.update(_db.plans)..where(
            (t) => plan.id == null
                ? const Constant(true)
                : t.id.isNotValue(plan.id!),
          ))
          .write(const PlansCompanion(active: Value(false)));
    }
    final row = PlansCompanion(
      id: plan.id == null ? const Value.absent() : Value(plan.id!),
      name: const Value(''),
      fromAyah: Value(plan.fromAyah),
      toAyah: Value(plan.toAyah),
      unit: Value(plan.unit.name),
      amount: Value(plan.amount.toDouble()),
      daysPerWeek: Value(plan.studyDays.length),
      weekdays: Value(plan.weekdayMask),
      backward: Value(plan.backward),
      active: Value(plan.active),
      createdAt: Value(plan.createdAt),
    );
    return _db.into(_db.plans).insertOnConflictUpdate(row);
  });

  static MemorizationPlan _plan(PlanRow r) => MemorizationPlan(
    id: r.id,
    fromAyah: r.fromAyah,
    toAyah: r.toAyah,
    unit: PlanUnit.values.byName(r.unit),
    amount: r.amount.round(),
    studyDays: MemorizationPlan.weekdaysOf(r.weekdays),
    backward: r.backward,
    active: r.active,
    createdAt: r.createdAt,
  );

  @override
  Future<List<AyahAttempt>> attemptsFor(int ayahId) async {
    final rows =
        await (_db.select(_db.attempts)
              ..where((t) => t.ayahId.equals(ayahId))
              ..orderBy([(t) => OrderingTerm.asc(t.at)]))
            .get();
    return [for (final r in rows) _attempt(r)];
  }

  static AyahAttempt _attempt(AttemptRow r) => AyahAttempt(
    ayahId: r.ayahId,
    sessionId: r.sessionId,
    at: r.at,
    grade: AyahGrade.values.byName(r.grade),
    words: r.words,
    wrong: r.wrong,
    skipped: r.skipped,
    selfCorrected: r.selfCorrected,
    pronunciation: r.pronunciation,
    hidden: r.hidden,
  );

  static AyahMemory _memory(MemorizedAyahRow r) => AyahMemory(
    ayahId: r.ayahId,
    status: MemoryStatus.values.byName(r.status),
    verified: r.verified,
    stability: r.stability,
    lastReviewed: r.lastReviewed,
    learnedOn: r.learnedOn,
    reviews: r.reviews,
  );

  static MemorizedAyahsCompanion _row(AyahMemory m) =>
      MemorizedAyahsCompanion.insert(
        ayahId: Value(m.ayahId),
        status: m.status.name,
        verified: m.verified,
        stability: Value(m.stability),
        lastReviewed: Value(m.lastReviewed),
        learnedOn: Value(m.learnedOn),
        reviews: Value(m.reviews),
      );
}
