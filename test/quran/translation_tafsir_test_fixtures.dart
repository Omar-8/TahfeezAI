// SYNTHETIC TEST FIXTURE — NOT REAL TRANSLATION/TAFSIR CONTENT.
//
// Matches `quran_test_fixtures.dart`'s ayah ids (surah 1, ayahs 1001-1007).
// `computeResourceChecksum` is used to build a genuinely valid checksum, so
// installing this fixture exercises the same verification path a real
// (non-tampered) resource install would.

import 'package:tahfeez_ai/core/downloads/resource_integrity.dart';
import 'package:tahfeez_ai/quran/domain/models/tafsir_models.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';

const testTranslationSlug = 'en-test-translation';
const testTafsirId = 'en-test-tafsir';

List<TranslationVerseText> _translationVerses(String slug) => [
  for (var verseNo = 1; verseNo <= 7; verseNo++)
    TranslationVerseText(
      slug: slug,
      chapterNo: 1,
      verseNo: verseNo,
      text: 'Test translation for verse $verseNo [1]',
      footnotes: const [
        TranslationFootnote(marker: 1, text: 'A test footnote.'),
      ],
      crossReferences: verseNo == 1
          ? const [(chapterNo: 1, verseNo: 2)]
          : const [],
    ),
];

String _checksumFor(List<TranslationVerseText> verses) {
  final sorted = [...verses]..sort((a, b) => a.verseNo.compareTo(b.verseNo));
  return computeResourceChecksum([
    for (final v in sorted) '${v.chapterNo}:${v.verseNo}:${v.text}',
  ]);
}

TranslationBook buildTestTranslationBook({int version = 1, String? slug}) {
  final id = slug ?? testTranslationSlug;
  return TranslationBook(
    slug: id,
    displayName: 'Test Translation',
    languageCode: 'en',
    author: 'Test Author',
    version: version,
    source: 'https://example.invalid/translations/en-test',
    license: 'Test License — synthetic fixture only',
    checksum: _checksumFor(_translationVerses(id)),
  );
}

List<TranslationVerseText> buildTestTranslationVerses({String? slug}) =>
    _translationVerses(slug ?? testTranslationSlug);

List<TafsirVerseText> _tafsirVerses(String id) => [
  for (var verseNo = 1; verseNo <= 7; verseNo++)
    TafsirVerseText(
      tafsirId: id,
      chapterNo: 1,
      verseNo: verseNo,
      text: 'Test commentary for verse $verseNo.',
    ),
];

String _tafsirChecksumFor(List<TafsirVerseText> verses) {
  final sorted = [...verses]..sort((a, b) => a.verseNo.compareTo(b.verseNo));
  return computeResourceChecksum([
    for (final v in sorted) '${v.chapterNo}:${v.verseNo}:${v.text}',
  ]);
}

TafsirWork buildTestTafsirWork({int version = 1, String? id}) {
  final workId = id ?? testTafsirId;
  return TafsirWork(
    id: workId,
    displayName: 'Test Tafsir',
    languageCode: 'en',
    author: 'Test Author',
    version: version,
    source: 'https://example.invalid/tafsirs/en-test',
    license: 'Test License — synthetic fixture only',
    checksum: _tafsirChecksumFor(_tafsirVerses(workId)),
  );
}

List<TafsirVerseText> buildTestTafsirVerses({String? id}) =>
    _tafsirVerses(id ?? testTafsirId);
