import 'package:drift/drift.dart';

import '../../domain/models/mushaf_models.dart';
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

  /// `null` only for a [MushafLineType.surahHeader] or
  /// [MushafLineType.bismillah] line — see [MushafLine]'s doc comment.
  ///
  /// `@ReferenceName` disambiguates this from [endAyahId] below — both
  /// reference `Ayahs`, and without distinct names drift's (unused, here)
  /// reverse-relation "manager" API can't tell them apart.
  @ReferenceName('mushafLinesStartingHere')
  IntColumn get startAyahId => integer().nullable().references(
    Ayahs,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get startWordIndex => integer().nullable()();
  @ReferenceName('mushafLinesEndingHere')
  IntColumn get endAyahId => integer().nullable().references(
    Ayahs,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get endWordIndex => integer().nullable()();
  IntColumn get surahNo => integer().nullable().references(Surahs, #surahNo)();

  @override
  Set<Column> get primaryKey => {mushafId, pageNumber, lineNumber};
}
