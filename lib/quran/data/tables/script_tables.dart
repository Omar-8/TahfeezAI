import 'package:drift/drift.dart';

/// `id` is supplied by the dataset source (like [Ayahs.id]), not
/// auto-generated — a [Mushaf]/[MushafLine] elsewhere in the same payload
/// references a script or variant by this id, so it must be stable and
/// known *before* the row is inserted, which an autoincrement column
/// cannot guarantee.
@DataClassName('QuranScriptRow')
class QuranScripts extends Table {
  IntColumn get id => integer()();
  TextColumn get code => text().unique()();
  TextColumn get displayName => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuranScriptVariantRow')
class QuranScriptVariants extends Table {
  IntColumn get id => integer()();
  IntColumn get scriptId => integer().references(QuranScripts, #id)();
  TextColumn get code => text()();
  TextColumn get displayName => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {scriptId, code},
  ];
}
