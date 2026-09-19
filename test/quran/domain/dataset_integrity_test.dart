import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/dataset_integrity.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

import '../quran_test_fixtures.dart';

DatasetMetadata get _metadata => DatasetMetadata(
  datasetVersion: 'v1',
  contentHash: 'abc123',
  importedAt: DateTime.utc(2024),
);

QuranDatasetPayload _emptyPayload({
  List<Surah> surahs = const [],
  List<SurahLocalization> surahLocalizations = const [],
  List<Ayah> ayahs = const [],
  List<AyahWord> ayahWords = const [],
  List<QuranScript> scripts = const [],
  List<QuranScriptVariant> scriptVariants = const [],
  List<Mushaf> mushafs = const [],
  List<MushafLine> mushafLines = const [],
  List<MushafToken> mushafTokens = const [],
  List<NavigationRange> navigationRanges = const [],
  DatasetMetadata? metadata,
}) {
  return QuranDatasetPayload(
    surahs: surahs,
    surahLocalizations: surahLocalizations,
    ayahs: ayahs,
    ayahWords: ayahWords,
    scripts: scripts,
    scriptVariants: scriptVariants,
    mushafs: mushafs,
    mushafLines: mushafLines,
    mushafTokens: mushafTokens,
    navigationRanges: navigationRanges,
    metadata: metadata ?? _metadata,
  );
}

Mushaf _testMushaf({int id = 1, int pageCount = 1, int linesPerPage = 5}) =>
    Mushaf(
      id: id,
      code: 'm$id',
      scriptId: 1,
      pageCount: pageCount,
      linesPerPage: linesPerPage,
      qiraah: 'Test',
      edition: 'Test',
      renderingType: MushafRenderingType.unicodeText,
    );

void main() {
  const validator = DatasetIntegrityValidator();

  bool hasCode(DatasetIntegrityReport report, String code) =>
      report.issues.any((i) => i.code == code);

  test('a fully valid synthetic dataset has no errors', () {
    final report = validator.validate(buildValidSyntheticPayload());
    expect(report.isValid, isTrue);
    expect(report.errors, isEmpty);
  });

  test('flags a surah count that is not exactly 114', () {
    final payload = _emptyPayload(
      surahs: [
        const Surah(
          surahNo: 1,
          ayahCount: 1,
          revelationOrder: 1,
          rukusCount: 1,
          revelationType: RevelationType.meccan,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(report.isValid, isFalse);
    expect(hasCode(report, 'surah_count'), isTrue);
  });

  test('flags a specific missing surah number', () {
    final surahs = [
      for (var n = 1; n <= 114; n++)
        if (n != 50)
          Surah(
            surahNo: n,
            ayahCount: 1,
            revelationOrder: n,
            rukusCount: 1,
            revelationType: RevelationType.meccan,
          ),
      // Pad back to 114 rows with a duplicate so only "surah_missing" fires,
      // not also "surah_count".
      const Surah(
        surahNo: 114,
        ayahCount: 1,
        revelationOrder: 999,
        rukusCount: 1,
        revelationType: RevelationType.meccan,
      ),
    ];
    final report = validator.validate(_emptyPayload(surahs: surahs));
    expect(hasCode(report, 'surah_missing'), isTrue);
  });

  test('flags a gap in ayah numbering', () {
    final payload = _emptyPayload(
      surahs: [
        const Surah(
          surahNo: 1,
          ayahCount: 3,
          revelationOrder: 1,
          rukusCount: 1,
          revelationType: RevelationType.meccan,
        ),
      ],
      ayahs: const [
        Ayah(
          id: 1001,
          chapterNo: 1,
          verseNo: 1,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
        // verse 2 is missing entirely.
        Ayah(
          id: 1003,
          chapterNo: 1,
          verseNo: 3,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'ayah_numbering'), isTrue);
  });

  test('flags a duplicate stable ayah id', () {
    final payload = _emptyPayload(
      ayahs: const [
        Ayah(
          id: 1001,
          chapterNo: 1,
          verseNo: 1,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
        Ayah(
          id: 1001,
          chapterNo: 1,
          verseNo: 2,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'ayah_id_duplicate'), isTrue);
  });

  test('flags an ayah id that does not match the stable-id formula', () {
    final payload = _emptyPayload(
      ayahs: const [
        Ayah(
          id: 42,
          chapterNo: 1,
          verseNo: 1,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'ayah_id_unstable'), isTrue);
  });

  test('flags non-contiguous word indices within an ayah', () {
    final payload = _emptyPayload(
      ayahWords: const [
        AyahWord(ayahId: 1001, scriptId: 1, wordIndex: 0, text: 'a'),
        // index 1 skipped.
        AyahWord(ayahId: 1001, scriptId: 1, wordIndex: 2, text: 'b'),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'word_indices_not_contiguous'), isTrue);
  });

  test('flags a Mushaf line referencing an unknown mushaf', () {
    final payload = _emptyPayload(
      mushafLines: const [
        MushafLine(
          mushafId: 999,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.surahHeader,
          isCentered: true,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'mushaf_line_unknown_mushaf'), isTrue);
  });

  test('flags a page number outside a Mushaf\'s declared page count', () {
    final payload = _emptyPayload(
      mushafs: [_testMushaf()],
      mushafLines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 2,
          lineNumber: 1,
          lineType: MushafLineType.surahHeader,
          isCentered: true,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'mushaf_page_out_of_range'), isTrue);
  });

  test('flags non-contiguous line numbers on a Mushaf page', () {
    final payload = _emptyPayload(
      mushafs: [_testMushaf()],
      mushafLines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.surahHeader,
          isCentered: true,
        ),
        // line 2 skipped.
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 3,
          lineType: MushafLineType.surahHeader,
          isCentered: true,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'mushaf_lines_not_contiguous'), isTrue);
  });

  test('flags a Quran-text line missing its token range', () {
    final payload = _emptyPayload(
      mushafs: [_testMushaf()],
      mushafLines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.quranText,
          isCentered: false,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'line_missing_token_range'), isTrue);
  });

  test('flags a line referencing a token id that does not exist', () {
    final payload = _emptyPayload(
      mushafs: [_testMushaf()],
      mushafLines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.quranText,
          isCentered: false,
          firstTokenId: 1,
          lastTokenId: 2,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'line_references_unknown_token'), isTrue);
  });

  test('flags a line whose first token id is after its last token id', () {
    final payload = _emptyPayload(
      mushafs: [_testMushaf()],
      mushafTokens: const [
        MushafToken(
          mushafId: 1,
          sourceTokenId: 1,
          sequenceIndex: 0,
          tokenType: MushafTokenType.ayahMarker,
          displayText: 'a',
        ),
        MushafToken(
          mushafId: 1,
          sourceTokenId: 2,
          sequenceIndex: 1,
          tokenType: MushafTokenType.ayahMarker,
          displayText: 'b',
        ),
      ],
      mushafLines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.quranText,
          isCentered: false,
          firstTokenId: 2,
          lastTokenId: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'line_range_reversed'), isTrue);
  });

  test(
    'flags a navigation range with bounds outside its surah\'s ayah count',
    () {
      final payload = _emptyPayload(
        surahs: [
          const Surah(
            surahNo: 1,
            ayahCount: 5,
            revelationOrder: 1,
            rukusCount: 1,
            revelationType: RevelationType.meccan,
          ),
        ],
        navigationRanges: const [
          NavigationRange(
            type: NavigationUnitType.juz,
            unitNo: 1,
            surahNo: 1,
            startAyahNo: 1,
            endAyahNo: 10,
          ),
        ],
      );
      final report = validator.validate(payload);
      expect(hasCode(report, 'navigation_range_invalid_bounds'), isTrue);
    },
  );

  test('flags a navigation range referencing an unknown surah', () {
    final payload = _emptyPayload(
      navigationRanges: const [
        NavigationRange(
          type: NavigationUnitType.juz,
          unitNo: 1,
          surahNo: 999,
          startAyahNo: 1,
          endAyahNo: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'navigation_range_unknown_surah'), isTrue);
  });

  test('flags an ayah with no word text in any script', () {
    final payload = _emptyPayload(
      ayahs: const [
        Ayah(
          id: 1001,
          chapterNo: 1,
          verseNo: 1,
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'ayah_missing_text'), isTrue);
  });

  test('flags a blank word', () {
    final payload = _emptyPayload(
      ayahWords: const [
        AyahWord(ayahId: 1001, scriptId: 1, wordIndex: 0, text: '   '),
      ],
    );
    final report = validator.validate(payload);
    expect(hasCode(report, 'ayah_word_blank'), isTrue);
  });

  test('flags missing dataset version/hash metadata', () {
    final report = validator.validate(
      _emptyPayload(
        metadata: DatasetMetadata(
          datasetVersion: '',
          contentHash: '',
          importedAt: DateTime.utc(2024),
        ),
      ),
    );
    expect(hasCode(report, 'metadata_missing_version'), isTrue);
    expect(hasCode(report, 'metadata_missing_hash'), isTrue);
  });
}
