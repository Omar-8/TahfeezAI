import 'package:drift/drift.dart';

/// One installed WBW language pack's metadata. `id` is the dataset-supplied
/// stable pack id (e.g. `'en-clearquran'`), not autoincremented — see
/// `WbwLanguagePack`'s doc comment for why pack identity must be stable
/// across installs/updates.
@DataClassName('WbwPackRow')
class WbwPacks extends Table {
  TextColumn get id => text()();
  TextColumn get languageCode => text()();
  TextColumn get displayName => text()();
  IntColumn get version => integer()();
  TextColumn get checksum => text()();
  TextColumn get source => text()();
  TextColumn get license => text()();
  BoolColumn get hasTranslation => boolean()();
  BoolColumn get hasTransliteration => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One word's translation/transliteration for one installed pack. Deleting a
/// [WbwPacks] row cascades to its words — an uninstall must never leave
/// orphaned word rows behind.
@DataClassName('WbwWordRow')
class WbwWords extends Table {
  TextColumn get packId =>
      text().references(WbwPacks, #id, onDelete: KeyAction.cascade)();
  IntColumn get ayahId => integer()();
  IntColumn get wordIndex => integer()();
  TextColumn get translation => text().nullable()();
  TextColumn get transliteration => text().nullable()();

  @override
  Set<Column> get primaryKey => {packId, ayahId, wordIndex};
}
