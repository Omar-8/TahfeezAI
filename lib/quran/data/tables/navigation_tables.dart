import 'package:drift/drift.dart';

import '../../domain/models/navigation_models.dart';
import 'surah_tables.dart';

@DataClassName('NavigationRangeRow')
class NavigationRanges extends Table {
  TextColumn get type => textEnum<NavigationUnitType>()();
  IntColumn get unitNo => integer()();
  IntColumn get surahNo => integer().references(Surahs, #surahNo)();
  IntColumn get startAyahNo => integer()();
  IntColumn get endAyahNo => integer()();

  @override
  Set<Column> get primaryKey => {type, unitNo, surahNo};
}
