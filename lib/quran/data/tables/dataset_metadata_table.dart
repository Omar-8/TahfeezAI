import 'package:drift/drift.dart';

/// Single-row table (by convention, always [id] `0`) recording which
/// dataset is currently imported. See [DatasetMetadata] for why this
/// exists.
@DataClassName('DatasetMetadataRow')
class DatasetMetadataEntries extends Table {
  IntColumn get id => integer()();
  TextColumn get datasetVersion => text()();
  TextColumn get contentHash => text()();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
