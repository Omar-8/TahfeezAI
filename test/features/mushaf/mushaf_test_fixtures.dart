// SYNTHETIC TEST FIXTURE — NOT REAL QURAN TEXT.
//
// Every string/number in this file is fabricated purely to exercise the
// Mushaf renderer's plumbing (page/line layout, chapter transitions,
// centered final lines). None of it is, or is derived from, actual Quran
// text, and none of it is ever bundled into the shipped app — see
// `docs/DATA_RESOURCE_REQUIREMENTS.md` for how a real, license-verified
// dataset will eventually be sourced.
//
// Unlike `test/quran/quran_test_fixtures.dart`'s single-page fixture, this
// one models five pages matching this milestone's explicit "representative
// pages" list: an opening chapter, the beginning of a longer chapter, a
// plain mid-chapter page, a page spanning a chapter transition, and a
// final page ending in a short, centered line.

import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

const mushafTestScriptId = 1;
const mushafTestScriptCode = 'mushaf_synthetic_test_script';
const mushafTestMushafId = 1;

/// Chapter numbers this fixture gives non-filler ayah counts, keyed to the
/// representative page each backs.
const _fatihaLikeSurah = 1; // Page 1: opening chapter.
const _baqarahLikeSurah = 2; // Page 2: beginning of a longer chapter.
const _middleSurah = 50; // Page 3: a plain mid-chapter page.
const _transitionFromSurah = 55; // Page 4: chapter transition (ends here).
const _transitionToSurah = 56; // Page 4: chapter transition (begins here).
const _finalSurah = 114; // Page 5: the final page.

const Map<int, int> _ayahCounts = {
  _fatihaLikeSurah: 7,
  _baqarahLikeSurah: 10,
  _middleSurah: 8,
  _transitionFromSurah: 6,
  _transitionToSurah: 4,
  _finalSurah: 6,
};

QuranDatasetPayload buildMushafTestPayload() {
  final surahs = <Surah>[];
  final ayahs = <Ayah>[];
  final words = <AyahWord>[];

  for (var surahNo = 1; surahNo <= 114; surahNo++) {
    final ayahCount = _ayahCounts[surahNo] ?? 2;
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
          juzNo: surahNo == _fatihaLikeSurah ? 1 : 2,
          hizbNo: surahNo == _fatihaLikeSurah ? 1 : 3,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: mushafTestScriptId,
          wordIndex: 0,
          text: 'lafz',
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: mushafTestScriptId,
          wordIndex: 1,
          text: 'kalima',
        ),
      );
    }
  }

  int ayahId(int surahNo, int verseNo) => surahNo * 1000 + verseNo;

  final mushafLines = <MushafLine>[
    // Page 1 -- opening chapter: header, Bismillah, then justified lines
    // ending in a short, centered final line (the last verse alone).
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 1,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: _fatihaLikeSurah,
    ),
    const MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 1,
      lineNumber: 2,
      lineType: MushafLineType.bismillah,
      isCentered: true,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 1,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_fatihaLikeSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_fatihaLikeSurah, 3),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 1,
      lineNumber: 4,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_fatihaLikeSurah, 4),
      startWordIndex: 0,
      endAyahId: ayahId(_fatihaLikeSurah, 6),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 1,
      lineNumber: 5,
      lineType: MushafLineType.quranText,
      isCentered: true,
      startAyahId: ayahId(_fatihaLikeSurah, 7),
      startWordIndex: 0,
      endAyahId: ayahId(_fatihaLikeSurah, 7),
      endWordIndex: 1,
    ),

    // Page 2 -- beginning of a longer chapter: header, Bismillah, three
    // justified text lines.
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 2,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: _baqarahLikeSurah,
    ),
    const MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 2,
      lineNumber: 2,
      lineType: MushafLineType.bismillah,
      isCentered: true,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 2,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_baqarahLikeSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_baqarahLikeSurah, 3),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 2,
      lineNumber: 4,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_baqarahLikeSurah, 4),
      startWordIndex: 0,
      endAyahId: ayahId(_baqarahLikeSurah, 7),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 2,
      lineNumber: 5,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_baqarahLikeSurah, 8),
      startWordIndex: 0,
      endAyahId: ayahId(_baqarahLikeSurah, 10),
      endWordIndex: 1,
    ),

    // Page 3 -- a plain mid-chapter page: no header/Bismillah at all.
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 3,
      lineNumber: 1,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_middleSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_middleSurah, 3),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 3,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_middleSurah, 4),
      startWordIndex: 0,
      endAyahId: ayahId(_middleSurah, 6),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 3,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_middleSurah, 7),
      startWordIndex: 0,
      endAyahId: ayahId(_middleSurah, 8),
      endWordIndex: 1,
    ),

    // Page 4 -- a chapter transition: the previous chapter's last (short,
    // centered) line, then the next chapter's header/Bismillah/text, all on
    // one page.
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 4,
      lineNumber: 1,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_transitionFromSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_transitionFromSurah, 3),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 4,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: true,
      startAyahId: ayahId(_transitionFromSurah, 4),
      startWordIndex: 0,
      endAyahId: ayahId(_transitionFromSurah, 6),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 4,
      lineNumber: 3,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: _transitionToSurah,
    ),
    const MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 4,
      lineNumber: 4,
      lineType: MushafLineType.bismillah,
      isCentered: true,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 4,
      lineNumber: 5,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_transitionToSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_transitionToSurah, 4),
      endWordIndex: 1,
    ),

    // Page 5 -- the final page: ends in a short, centered final line.
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 5,
      lineNumber: 1,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_finalSurah, 1),
      startWordIndex: 0,
      endAyahId: ayahId(_finalSurah, 2),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 5,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      startAyahId: ayahId(_finalSurah, 3),
      startWordIndex: 0,
      endAyahId: ayahId(_finalSurah, 4),
      endWordIndex: 1,
    ),
    MushafLine(
      mushafId: mushafTestMushafId,
      pageNumber: 5,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: true,
      startAyahId: ayahId(_finalSurah, 5),
      startWordIndex: 0,
      endAyahId: ayahId(_finalSurah, 6),
      endWordIndex: 1,
    ),
  ];

  return QuranDatasetPayload(
    surahs: surahs,
    surahLocalizations: const [
      SurahLocalization(
        surahNo: _fatihaLikeSurah,
        languageCode: 'en',
        name: 'Test Opening Chapter',
      ),
      SurahLocalization(
        surahNo: _baqarahLikeSurah,
        languageCode: 'en',
        name: 'Test Long Chapter',
      ),
      SurahLocalization(
        surahNo: _transitionToSurah,
        languageCode: 'en',
        name: 'Test Transition Chapter',
      ),
      SurahLocalization(
        surahNo: _finalSurah,
        languageCode: 'en',
        name: 'Test Final Chapter',
      ),
    ],
    ayahs: ayahs,
    ayahWords: words,
    scripts: const [
      QuranScript(
        id: mushafTestScriptId,
        code: mushafTestScriptCode,
        displayName: 'Synthetic Mushaf Test Script',
      ),
    ],
    scriptVariants: const [],
    mushafs: const [
      Mushaf(
        id: mushafTestMushafId,
        code: 'synthetic_mushaf_test',
        scriptId: mushafTestScriptId,
        pageCount: 5,
        linesPerPage: 5,
      ),
    ],
    mushafLines: mushafLines,
    navigationRanges: const [
      NavigationRange(
        type: NavigationUnitType.juz,
        unitNo: 1,
        surahNo: _fatihaLikeSurah,
        startAyahNo: 1,
        endAyahNo: 7,
      ),
      NavigationRange(
        type: NavigationUnitType.hizb,
        unitNo: 1,
        surahNo: _fatihaLikeSurah,
        startAyahNo: 1,
        endAyahNo: 7,
      ),
    ],
    metadata: DatasetMetadata(
      datasetVersion: 'mushaf-synthetic-test-fixture-1',
      contentHash: 'deadbeef-mushaf',
      importedAt: DateTime.utc(2024),
    ),
  );
}
