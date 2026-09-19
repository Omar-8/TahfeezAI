import 'package:drift/drift.dart';

import 'tables/tafsir_tables.dart';

part 'tafsir_database.g.dart';

/// The tafsir resource database: installed tafsir works and their per-verse
/// commentary text. Mirrors `TranslationDatabase`'s rationale — its own
/// physically separate `@DriftDatabase`, schema-only.
@DriftDatabase(tables: [TafsirWorks, TafsirVerses])
class TafsirDatabase extends _$TafsirDatabase {
  TafsirDatabase(super.connection);

  @override
  int get schemaVersion => 1;
}
