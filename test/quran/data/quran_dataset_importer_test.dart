import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_integrity_exception.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

import '../quran_test_fixtures.dart';

void main() {
  late QuranDatabase db;

  setUp(() => db = QuranDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('imports a valid dataset and makes it queryable', () async {
    const importer = QuranDatasetImporter();
    final report = await importer.import(db, buildValidSyntheticPayload());

    expect(report.isValid, isTrue);
    final surahCount = await db.select(db.surahs).get();
    expect(surahCount, hasLength(114));
  });

  test('refuses an invalid dataset and writes nothing', () async {
    const importer = QuranDatasetImporter();
    final invalidPayload = QuranDatasetPayload(
      surahs: const [],
      surahLocalizations: const [],
      ayahs: const [],
      ayahWords: const [],
      scripts: const [],
      scriptVariants: const [],
      mushafs: const [],
      mushafLines: const [],
      navigationRanges: const [],
      metadata: DatasetMetadata(
        datasetVersion: 'bad',
        contentHash: 'bad',
        importedAt: DateTime.utc(2024),
      ),
    );

    await expectLater(
      () => importer.import(db, invalidPayload),
      throwsA(isA<DatasetIntegrityException>()),
    );

    final surahCount = await db.select(db.surahs).get();
    expect(surahCount, isEmpty);
  });

  test('a second import fully replaces the first (no leftover rows)', () async {
    const importer = QuranDatasetImporter();
    await importer.import(db, buildValidSyntheticPayload());
    await importer.import(db, buildValidSyntheticPayload());

    final surahCount = await db.select(db.surahs).get();
    expect(surahCount, hasLength(114));
  });
}
