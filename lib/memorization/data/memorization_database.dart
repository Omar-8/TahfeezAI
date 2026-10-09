import 'package:drift/drift.dart';

part 'memorization_database.g.dart';

/// The memory of each tracked ayah (`AyahMemory`).
@DataClassName('MemorizedAyahRow')
class MemorizedAyahs extends Table {
  IntColumn get ayahId => integer()();

  /// `MemoryStatus.name`.
  TextColumn get status => text()();
  BoolColumn get verified => boolean()();
  RealColumn get stability => real().nullable()();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get learnedOn => dateTime().nullable()();
  IntColumn get reviews => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {ayahId};
}

/// Every ayah's result in every test (`AyahAttempt`).
@DataClassName('AttemptRow')
class Attempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  IntColumn get ayahId => integer()();
  DateTimeColumn get at => dateTime()();

  /// `AyahGrade.name`.
  TextColumn get grade => text()();
  IntColumn get words => integer()();
  IntColumn get wrong => integer()();
  IntColumn get skipped => integer()();
  IntColumn get selfCorrected => integer()();
  IntColumn get pronunciation => integer()();
  BoolColumn get hidden => boolean()();
}

/// Memorization plans (Milestone 17, phase M3): a range learned a set
/// amount a day.
@DataClassName('PlanRow')
class Plans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get fromAyah => integer()();
  IntColumn get toAyah => integer()();

  /// `ayahs` / `halfPages` / `pages`.
  TextColumn get unit => text()();
  RealColumn get amount => real()();
  IntColumn get daysPerWeek => integer()();

  /// Learned from [toAyah] back to [fromAyah] (e.g. An-Nas to An-Naba).
  BoolColumn get backward => boolean()();
  BoolColumn get active => boolean()();
  DateTimeColumn get createdAt => dateTime()();
}

/// The memorization database: mutable user data, physically separate from
/// the immutable Quran databases (`docs/ARCHITECTURE.md` §4). Schema only;
/// queries live in `DriftMemorizationRepository`.
@DriftDatabase(tables: [MemorizedAyahs, Attempts, Plans])
class MemorizationDatabase extends _$MemorizationDatabase {
  MemorizationDatabase(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(
        Index(
          'attempts_ayah',
          'CREATE INDEX attempts_ayah ON attempts (ayah_id)',
        ),
      );
    },
  );
}
