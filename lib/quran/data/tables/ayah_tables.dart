import 'package:drift/drift.dart';

import '../../domain/models/ayah_models.dart';
import 'script_tables.dart';
import 'surah_tables.dart';

@DataClassName('AyahRow')
class Ayahs extends Table {
  /// Stable id: `chapterNo * 1000 + verseNo`. See [Ayah.id]'s doc comment
  /// for why this numbering scheme is safe.
  IntColumn get id => integer()();
  IntColumn get chapterNo => integer().references(Surahs, #surahNo)();
  IntColumn get verseNo => integer()();
  IntColumn get juzNo => integer()();
  IntColumn get hizbNo => integer()();
  IntColumn get rubNo => integer()();
  IntColumn get manzilNo => integer()();
  IntColumn get rukuNo => integer()();
  TextColumn get sajdah => textEnum<SajdahType>().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {chapterNo, verseNo},
  ];
}

@DataClassName('AyahWordRow')
class AyahWords extends Table {
  IntColumn get ayahId => integer().references(Ayahs, #id)();
  IntColumn get scriptId => integer().references(QuranScripts, #id)();
  IntColumn get wordIndex => integer()();

  /// Named `wordText`, not `text` — a column getter literally named `text`
  /// shadows `Table.text()` (the DSL factory method every column
  /// definition here calls), which silently corrupts how drift_dev's
  /// analyzer parses this table (confirmed empirically while building this
  /// milestone: it throws a `FunctionExpressionInvocationImpl` cast error
  /// deep in `drift_dev`'s column parser). Worth remembering for every
  /// future table: never name a column the same as a `Table` DSL method
  /// (`text`, `integer`, `boolean`, `dateTime`, `blob`, ...).
  TextColumn get wordText => text()();

  @override
  Set<Column> get primaryKey => {ayahId, scriptId, wordIndex};
}
