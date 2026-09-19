import 'package:drift/drift.dart';

import '../../domain/models/mushaf_models.dart';
import '../../domain/models/mushaf_token_models.dart';
import 'ayah_tables.dart';
import 'script_tables.dart';
import 'surah_tables.dart';

/// `id` is supplied by the dataset source, not auto-generated — see
/// [QuranScripts]' doc comment for why (a [MushafLine] in the same payload
/// references a Mushaf by this id before it is inserted).
@DataClassName('MushafRow')
class Mushafs extends Table {
  IntColumn get id => integer()();
  TextColumn get code => text().unique()();
  IntColumn get scriptId => integer().references(QuranScripts, #id)();
  IntColumn get scriptVariantId =>
      integer().nullable().references(QuranScriptVariants, #id)();
  IntColumn get pageCount => integer()();
  IntColumn get linesPerPage => integer()();
  TextColumn get qiraah => text()();
  TextColumn get edition => text()();
  TextColumn get renderingType => textEnum<MushafRenderingType>()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MushafLineRow')
class MushafLines extends Table {
  IntColumn get mushafId =>
      integer().references(Mushafs, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  IntColumn get lineNumber => integer()();
  TextColumn get lineType => textEnum<MushafLineType>()();
  BoolColumn get isCentered => boolean()();

  /// [MushafToken.sourceTokenId] bounds this line spans — `null` only for a
  /// [MushafLineType.surahHeader] or [MushafLineType.bismillah] line. Not a
  /// foreign key: [MushafTokens]' key is the composite
  /// `(mushafId, sourceTokenId)`, which Drift cannot express a single-column
  /// reference against — validated instead by `DatasetIntegrityValidator`
  /// at import time, the same way every other cross-table dataset
  /// invariant in this file is enforced before import rather than by a
  /// database-level constraint.
  IntColumn get firstTokenId => integer().nullable()();
  IntColumn get lastTokenId => integer().nullable()();
  IntColumn get surahNo => integer().nullable().references(Surahs, #surahNo)();

  @override
  Set<Column> get primaryKey => {mushafId, pageNumber, lineNumber};
}

/// One [MushafToken] — the printed token stream a [MushafLine]'s
/// `firstTokenId`/`lastTokenId` range resolves against. See
/// `lib/quran/domain/models/mushaf_token_models.dart` for why this is a
/// concept separate from [AyahWords].
@DataClassName('MushafTokenRow')
class MushafTokens extends Table {
  IntColumn get mushafId =>
      integer().references(Mushafs, #id, onDelete: KeyAction.cascade)();
  IntColumn get sourceTokenId => integer()();
  IntColumn get sequenceIndex => integer()();
  TextColumn get tokenType => textEnum<MushafTokenType>()();
  TextColumn get displayText => text()();
  IntColumn get surahNumber => integer().nullable()();
  IntColumn get ayahNumber => integer().nullable()();
  IntColumn get sourceWordPosition => integer().nullable()();

  /// Set only for [MushafTokenType.quranWord] tokens — never fabricated for
  /// a marker. Not declared as a foreign key to [Ayahs]: doing so would
  /// require every insert to satisfy it before [canonicalWordIndex] can
  /// even be checked, whereas `DatasetIntegrityValidator` already validates
  /// this pair resolves to a real [AyahWords] row before any import runs.
  IntColumn get canonicalAyahId => integer().nullable()();
  IntColumn get canonicalWordIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {mushafId, sourceTokenId};
}
