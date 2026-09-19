// SYNTHETIC TEST FIXTURE — NOT REAL QURAN TEXT.
//
// Every string/number in this file is fabricated purely to exercise the
// Quran data engine's plumbing (schema, batching, integrity validation).
// None of it is, or is derived from, actual Quran text, and none of it is
// ever bundled into the shipped app — see `docs/DATA_RESOURCE_REQUIREMENTS.md`
// for how a real, license-verified dataset will eventually be sourced.

import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

const testScriptId = 1;
const testScriptCode = 'synthetic_test_script';

/// A fully valid, self-consistent, 114-"surah" synthetic payload —
/// satisfying every rule in `DatasetIntegrityValidator`, so it can be
/// imported and queried through the whole stack. Surah 1 gets richer
/// content (7 ayahs, a one-page Mushaf, one Juz/Hizb) for tests that need
/// something to actually navigate; surahs 2-114 are minimal filler so the
/// "exactly 114 surahs" rule is satisfied without 114 hand-authored blocks.
QuranDatasetPayload buildValidSyntheticPayload() {
  final surahs = <Surah>[];
  final ayahs = <Ayah>[];
  final words = <AyahWord>[];

  for (var surahNo = 1; surahNo <= 114; surahNo++) {
    final ayahCount = surahNo == 1 ? 7 : 2;
    surahs.add(
      Surah(
        surahNo: surahNo,
        ayahCount: ayahCount,
        revelationOrder: surahNo,
        rukusCount: 1,
        revelationType: surahNo.isOdd
            ? RevelationType.meccan
            : RevelationType.medinan,
      ),
    );

    for (var verseNo = 1; verseNo <= ayahCount; verseNo++) {
      final ayahId = surahNo * 1000 + verseNo;
      ayahs.add(
        Ayah(
          id: ayahId,
          chapterNo: surahNo,
          verseNo: verseNo,
          juzNo: surahNo == 1 ? 1 : 2,
          hizbNo: surahNo == 1 ? 1 : 3,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      );

      // Two synthetic "words" per ayah, contiguous 0-based indices.
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: testScriptId,
          wordIndex: 0,
          text: 'lafz',
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: testScriptId,
          wordIndex: 1,
          text: 'kalima',
        ),
      );
    }
  }

  const mushafId = 1;

  // Mushaf tokens mirror surah 1's own AyahWords 1:1 (all real quranWord
  // tokens, no markers) — line 2 spans ayahs 1001-1004, line 3 spans
  // 1005-1007, matching each line's declared token range below.
  final mushafTokens = <MushafToken>[];
  var tokenCounter = 1;
  for (var verseNo = 1; verseNo <= 7; verseNo++) {
    for (var w = 0; w < 2; w++) {
      mushafTokens.add(
        MushafToken(
          mushafId: mushafId,
          sourceTokenId: tokenCounter,
          sequenceIndex: tokenCounter - 1,
          tokenType: MushafTokenType.quranWord,
          displayText: w == 0 ? 'lafz' : 'kalima',
          surahNumber: 1,
          ayahNumber: verseNo,
          sourceWordPosition: w + 1,
          canonicalAyahId: 1000 + verseNo,
          canonicalWordIndex: w,
        ),
      );
      tokenCounter++;
    }
  }

  final mushafLines = [
    const MushafLine(
      mushafId: mushafId,
      pageNumber: 1,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: 1,
    ),
    const MushafLine(
      mushafId: mushafId,
      pageNumber: 1,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: 1,
      lastTokenId: 8,
    ),
    const MushafLine(
      mushafId: mushafId,
      pageNumber: 1,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: 9,
      lastTokenId: 14,
    ),
  ];

  return QuranDatasetPayload(
    surahs: surahs,
    surahLocalizations: const [
      SurahLocalization(
        surahNo: 1,
        languageCode: 'en',
        name: 'Test Chapter One',
        meaning: 'The First Test',
      ),
    ],
    ayahs: ayahs,
    ayahWords: words,
    scripts: const [
      QuranScript(
        id: testScriptId,
        code: testScriptCode,
        displayName: 'Synthetic Test Script',
      ),
    ],
    scriptVariants: const [],
    mushafs: const [
      Mushaf(
        id: mushafId,
        code: 'synthetic_mushaf',
        scriptId: testScriptId,
        pageCount: 1,
        linesPerPage: 3,
        qiraah: 'Test',
        edition: 'Test',
        renderingType: MushafRenderingType.unicodeText,
      ),
    ],
    mushafLines: mushafLines,
    mushafTokens: mushafTokens,
    navigationRanges: const [
      NavigationRange(
        type: NavigationUnitType.juz,
        unitNo: 1,
        surahNo: 1,
        startAyahNo: 1,
        endAyahNo: 7,
      ),
      NavigationRange(
        type: NavigationUnitType.hizb,
        unitNo: 1,
        surahNo: 1,
        startAyahNo: 1,
        endAyahNo: 7,
      ),
    ],
    metadata: DatasetMetadata(
      datasetVersion: 'synthetic-test-fixture-1',
      contentHash: 'deadbeef',
      importedAt: DateTime.utc(2024),
    ),
  );
}
