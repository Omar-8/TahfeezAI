// SYNTHETIC TEST FIXTURE — NOT REAL QURAN TEXT.
//
// A second, richer fixture (distinct from `quran_test_fixtures.dart`'s
// single-script payload) proving Milestone 8's "not every script has
// identical word strings/page mappings/page count/line count" requirement:
// two scripts share the same canonical surahs/ayahs but have divergent word
// text and entirely separate Mushaf pagination.

import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

const multiScriptAId = 1;
const multiScriptACode = 'multi_script_a';
const multiScriptAMushafId = 1;

const multiScriptBId = 2;
const multiScriptBCode = 'multi_script_b';
const multiScriptBMushafId = 2;

/// 114 surahs (surah 1 gets 7 ayahs, like `buildValidSyntheticPayload()`),
/// two scripts with different word text for the same ayahs, and two Mushafs
/// with different page counts/line layouts for the same content.
QuranDatasetPayload buildMultiScriptSyntheticPayload() {
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

      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: multiScriptAId,
          wordIndex: 0,
          text: 'lafz',
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: multiScriptAId,
          wordIndex: 1,
          text: 'kalima',
        ),
      );
      // Script B's word text is deliberately different — a script change
      // must actually change what text is shown, not just which font.
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: multiScriptBId,
          wordIndex: 0,
          text: 'harf',
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: multiScriptBId,
          wordIndex: 1,
          text: 'baab',
        ),
      );
    }
  }

  // Each Mushaf gets its own independent token-id space (ids 1..14, mirroring
  // its own 7-ayah x 2-word span) — real Mushaf editions from different
  // sources are not guaranteed to share a numbering scheme.
  List<MushafToken> tokensFor(int mushafId) {
    final tokens = <MushafToken>[];
    var tokenCounter = 1;
    for (var verseNo = 1; verseNo <= 7; verseNo++) {
      for (var w = 0; w < 2; w++) {
        tokens.add(
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
    return tokens;
  }

  final mushafATokens = tokensFor(multiScriptAMushafId);
  final mushafBTokens = tokensFor(multiScriptBMushafId);

  // Script A's Mushaf: one page, three lines — the same layout
  // `buildValidSyntheticPayload()` uses.
  final mushafALines = [
    const MushafLine(
      mushafId: multiScriptAMushafId,
      pageNumber: 1,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: 1,
    ),
    const MushafLine(
      mushafId: multiScriptAMushafId,
      pageNumber: 1,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: 1,
      lastTokenId: 8,
    ),
    const MushafLine(
      mushafId: multiScriptAMushafId,
      pageNumber: 1,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: 9,
      lastTokenId: 14,
    ),
  ];

  // Script B's Mushaf: the *same* ayahs (1001-1007) laid out across two
  // pages instead of one — a different page count and a different
  // line-to-ayah mapping for the identical canonical content, proving a
  // script really does carry its own independent pagination.
  final mushafBLines = [
    const MushafLine(
      mushafId: multiScriptBMushafId,
      pageNumber: 1,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: 1,
    ),
    const MushafLine(
      mushafId: multiScriptBMushafId,
      pageNumber: 1,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: 1,
      lastTokenId: 8,
    ),
    const MushafLine(
      mushafId: multiScriptBMushafId,
      pageNumber: 2,
      lineNumber: 1,
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
        id: multiScriptAId,
        code: multiScriptACode,
        displayName: 'Script A',
      ),
      QuranScript(
        id: multiScriptBId,
        code: multiScriptBCode,
        displayName: 'Script B',
      ),
    ],
    scriptVariants: const [],
    mushafs: const [
      Mushaf(
        id: multiScriptAMushafId,
        code: 'script_a_mushaf',
        scriptId: multiScriptAId,
        pageCount: 1,
        linesPerPage: 3,
        qiraah: 'Test',
        edition: 'Test',
        renderingType: MushafRenderingType.unicodeText,
      ),
      Mushaf(
        id: multiScriptBMushafId,
        code: 'script_b_mushaf',
        scriptId: multiScriptBId,
        pageCount: 2,
        linesPerPage: 2,
        qiraah: 'Test',
        edition: 'Test',
        renderingType: MushafRenderingType.unicodeText,
      ),
    ],
    mushafLines: [...mushafALines, ...mushafBLines],
    mushafTokens: [...mushafATokens, ...mushafBTokens],
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
      datasetVersion: 'multi-script-synthetic-test-fixture-1',
      contentHash: 'deadbeef2',
      importedAt: DateTime.utc(2024),
    ),
  );
}
