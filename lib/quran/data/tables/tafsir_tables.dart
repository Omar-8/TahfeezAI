import 'package:drift/drift.dart';

@DataClassName('TafsirWorkRow')
class TafsirWorks extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get languageCode => text()();
  TextColumn get author => text()();
  IntColumn get version => integer()();
  TextColumn get source => text()();
  TextColumn get license => text()();
  TextColumn get checksum => text()();
  IntColumn get formatVersion => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TafsirVerseRow')
class TafsirVerses extends Table {
  TextColumn get tafsirId =>
      text().references(TafsirWorks, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterNo => integer()();
  IntColumn get verseNo => integer()();
  TextColumn get verseText => text()();

  @override
  Set<Column> get primaryKey => {tafsirId, chapterNo, verseNo};
}
