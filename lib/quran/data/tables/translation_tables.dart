import 'package:drift/drift.dart';

/// One installed translation edition's metadata. `slug` is the
/// dataset-supplied stable id (e.g. `'en-hilali-khan'`), not autoincremented
/// — see `WbwPacks`' doc comment (`lib/wbw/data/tables/wbw_tables.dart`) for
/// why resource identity must be stable across installs/updates.
@DataClassName('TranslationBookRow')
class TranslationBooks extends Table {
  TextColumn get slug => text()();
  TextColumn get displayName => text()();
  TextColumn get languageCode => text()();
  TextColumn get author => text()();
  IntColumn get version => integer()();
  TextColumn get source => text()();
  TextColumn get license => text()();
  TextColumn get checksum => text()();
  IntColumn get formatVersion => integer()();

  @override
  Set<Column> get primaryKey => {slug};
}

/// One verse's translated text for one installed book. `footnotesJson`/
/// `crossReferencesJson` are nullable JSON-encoded lists — small, per-verse,
/// and never queried structurally, so a dedicated relational table would add
/// join cost with no real benefit over a JSON column here.
@DataClassName('TranslationVerseRow')
class TranslationVerses extends Table {
  TextColumn get slug =>
      text().references(TranslationBooks, #slug, onDelete: KeyAction.cascade)();
  IntColumn get chapterNo => integer()();
  IntColumn get verseNo => integer()();
  TextColumn get verseText => text()();
  TextColumn get footnotesJson => text().nullable()();
  TextColumn get crossReferencesJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {slug, chapterNo, verseNo};
}
