// SYNTHETIC TEST FIXTURE — NOT REAL WBW DATA.
//
// Matches `quran_test_fixtures.dart`'s `buildValidSyntheticPayload()`'s
// ayah ids (surah 1, ayahs 1001-1007, word indices 0/1).

import 'package:tahfeez_ai/wbw/domain/models/wbw_models.dart';

const testWbwPackId = 'en-test-pack';

WbwLanguagePack buildTestWbwPack({int version = 1}) => WbwLanguagePack(
  id: testWbwPackId,
  languageCode: 'en',
  displayName: 'Test English Pack',
  version: version,
  checksum: 'test-checksum-$version',
  source: 'https://example.invalid/wbw/en-test-pack',
  license: 'Test License — synthetic fixture only',
  hasTranslation: true,
  hasTransliteration: true,
);

List<WbwWordEntry> buildTestWbwWords({String? packId}) {
  final id = packId ?? testWbwPackId;
  return [
    for (var verseNo = 1; verseNo <= 7; verseNo++) ...[
      WbwWordEntry(
        packId: id,
        ayahId: 1000 + verseNo,
        wordIndex: 0,
        translation: 'word',
        transliteration: 'lafz',
      ),
      WbwWordEntry(
        packId: id,
        ayahId: 1000 + verseNo,
        wordIndex: 1,
        translation: 'phrase',
        transliteration: 'kalima',
      ),
    ],
  ];
}
