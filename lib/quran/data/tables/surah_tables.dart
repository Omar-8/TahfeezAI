import 'package:drift/drift.dart';

import '../../domain/models/surah_models.dart';

@DataClassName('SurahRow')
class Surahs extends Table {
  IntColumn get surahNo => integer()();
  IntColumn get ayahCount => integer()();
  IntColumn get revelationOrder => integer()();
  IntColumn get rukusCount => integer()();
  TextColumn get revelationType => textEnum<RevelationType>()();

  @override
  Set<Column> get primaryKey => {surahNo};
}

@DataClassName('SurahLocalizationRow')
class SurahLocalizations extends Table {
  IntColumn get surahNo => integer().references(Surahs, #surahNo)();
  TextColumn get languageCode => text()();
  TextColumn get name => text()();
  TextColumn get meaning => text().nullable()();

  @override
  Set<Column> get primaryKey => {surahNo, languageCode};
}
