import 'package:drift/drift.dart';

/// One ayah's normalized-text search index entry for one script — derived
/// from canonical `AyahWord` text (`SearchNormalizer.normalizeArabic`),
/// never a replacement for it. Rebuilt wholesale per script by
/// `DriftSearchRepository.indexQuranText`, per `docs/CLEAN_ROOM_RULES.md`'s
/// "search normalization must operate on derived/indexed representations."
///
/// Matching uses an indexed substring `LIKE` query over [normalizedText]
/// rather than SQLite FTS5: FTS5's own tokenizer would otherwise need
/// custom configuration to reproduce the exact same Arabic-specific
/// diacritic/alef-folding `SearchNormalizer` already performs in Dart
/// before storage, so a plain indexed column matched by `LIKE` achieves
/// the identical effective behavior more simply. This is the "equivalent
/// local indexed approach" this milestone's spec explicitly allows in
/// place of FTS5.
@TableIndex(name: 'idx_arabic_search_text', columns: {#normalizedText})
@DataClassName('ArabicSearchIndexRow')
class ArabicSearchIndexEntries extends Table {
  IntColumn get ayahId => integer()();
  TextColumn get scriptCode => text()();
  IntColumn get chapterNo => integer()();
  IntColumn get verseNo => integer()();
  TextColumn get normalizedText => text()();

  @override
  Set<Column> get primaryKey => {ayahId, scriptCode};
}

/// One verse's normalized-text search index entry for one installed
/// translation — derived from canonical `TranslationVerses.verseText`.
/// Rebuilt per translation slug by `indexTranslation`, and dropped
/// wholesale by `removeTranslationIndex` when that translation is deleted
/// (so a stale index never survives its source content).
@TableIndex(name: 'idx_translation_search_text', columns: {#normalizedText})
@DataClassName('TranslationSearchIndexRow')
class TranslationSearchIndexEntries extends Table {
  TextColumn get slug => text()();
  IntColumn get chapterNo => integer()();
  IntColumn get verseNo => integer()();
  TextColumn get normalizedText => text()();

  @override
  Set<Column> get primaryKey => {slug, chapterNo, verseNo};
}
