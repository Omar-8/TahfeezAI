import 'package:drift/drift.dart';

import '../domain/models/memorization_models.dart';
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
