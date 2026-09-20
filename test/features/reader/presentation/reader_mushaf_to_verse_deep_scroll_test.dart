// Regression test for a real, reported bug: switching from Mushaf mode to
// verse-by-verse mode while deep inside an already-loaded chapter lost the
// reading position and silently reset to that chapter's first ayah.
//
// Root cause: `Scrollable.ensureVisible` no-ops when the target ayah's
// widget was never built by the lazy `ListView.builder` (true for any ayah
// far from the list's current scroll position), so the old
// `_maybeScrollTo` silently did nothing while the app bar still showed the
// live Mushaf page's title -- exactly matching the user's report ("page 3
// in Mushaf mode... going to verse mode I start again from page 1").
//
// `mushaf_test_fixtures.dart`'s shared `buildMushafTestPayload()` gives
// every chapter at most 10 ayahs -- too few for the target ayah to land
// outside the initial viewport + cache-extent build range in a normal
// 800x600 test surface, so this uses its own dedicated fixture instead of
// risking a change to that widely-shared one. Per
// `dataset_integrity.dart`'s own checks, Mushaf-line/token coverage is a
// completely separate, optional-per-surah dataset from the canonical
// Surah/Ayah/AyahWord graph -- so only Surah 2 needs real Mushaf pages
// here; every other surah can have zero Mushaf coverage and still import
// cleanly.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/reader/application/reader_preferences_controller.dart';
import 'package:tahfeez_ai/features/reader/domain/reader_mode.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

const _scriptId = 1;
const _scriptCode = 'deep_scroll_synthetic_test_script';
const _mushafId = 1;
const _deepSurah = 2;
const _deepSurahAyahCount = 60;
const _page1LastAyah = 30; // Page 1: ayahs 1-30. Page 2: ayahs 31-60.

class _FixedReaderMode extends ReaderModePreferenceController {
  _FixedReaderMode(this._fixed);
  final ReaderMode _fixed;
  @override
  ReaderMode build() => _fixed;
}

QuranDatasetPayload _buildDeepSurahPayload() {
  final surahs = <Surah>[];
  final ayahs = <Ayah>[];
  final words = <AyahWord>[];

  for (var surahNo = 1; surahNo <= 114; surahNo++) {
    final ayahCount = surahNo == _deepSurah ? _deepSurahAyahCount : 2;
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
          juzNo: 1,
          hizbNo: 1,
          rubNo: 1,
          manzilNo: 1,
          rukuNo: 1,
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: _scriptId,
          wordIndex: 0,
          text: 'lafz',
        ),
      );
      words.add(
        AyahWord(
          ayahId: ayahId,
          scriptId: _scriptId,
          wordIndex: 1,
          text: 'kalima',
        ),
      );
    }
  }

  // Only Surah 2 gets Mushaf coverage -- split across two pages so its
  // *first* ayah (2:1) sits far from its *last* ayah (2:60) in reading
  // order, and its middle ayahs sit far enough into the verse-by-verse
  // list's own item order to be outside a normal test viewport's initial
  // lazy-build range.
  var tokenCounter = 1;
  final mushafTokens = <MushafToken>[];

  ({int first, int last}) tokenRange(int fromVerse, int toVerse) {
    final first = tokenCounter;
    for (var verseNo = fromVerse; verseNo <= toVerse; verseNo++) {
      for (var w = 0; w < 2; w++) {
        mushafTokens.add(
          MushafToken(
            mushafId: _mushafId,
            sourceTokenId: tokenCounter,
            sequenceIndex: tokenCounter - 1,
            tokenType: MushafTokenType.quranWord,
            displayText: w == 0 ? 'lafz' : 'kalima',
            surahNumber: _deepSurah,
            ayahNumber: verseNo,
            sourceWordPosition: w + 1,
            canonicalAyahId: _deepSurah * 1000 + verseNo,
            canonicalWordIndex: w,
          ),
        );
        tokenCounter++;
      }
    }
    return (first: first, last: tokenCounter - 1);
  }

  final page1Line1 = tokenRange(1, 10);
  final page1Line2 = tokenRange(11, 20);
  final page1Line3 = tokenRange(21, _page1LastAyah);
  final page2Line1 = tokenRange(_page1LastAyah + 1, 40);
  final page2Line2 = tokenRange(41, 50);
  final page2Line3 = tokenRange(51, _deepSurahAyahCount);

  final mushafLines = [
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 1,
      lineNumber: 1,
      lineType: MushafLineType.surahHeader,
      isCentered: true,
      surahNo: _deepSurah,
    ),
    const MushafLine(
      mushafId: _mushafId,
      pageNumber: 1,
      lineNumber: 2,
      lineType: MushafLineType.bismillah,
      isCentered: true,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 1,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page1Line1.first,
      lastTokenId: page1Line1.last,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 1,
      lineNumber: 4,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page1Line2.first,
      lastTokenId: page1Line2.last,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 1,
      lineNumber: 5,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page1Line3.first,
      lastTokenId: page1Line3.last,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 2,
      lineNumber: 1,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page2Line1.first,
      lastTokenId: page2Line1.last,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 2,
      lineNumber: 2,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page2Line2.first,
      lastTokenId: page2Line2.last,
    ),
    MushafLine(
      mushafId: _mushafId,
      pageNumber: 2,
      lineNumber: 3,
      lineType: MushafLineType.quranText,
      isCentered: false,
      firstTokenId: page2Line3.first,
      lastTokenId: page2Line3.last,
    ),
  ];

  return QuranDatasetPayload(
    surahs: surahs,
    surahLocalizations: const [
      SurahLocalization(
        surahNo: _deepSurah,
        languageCode: 'en',
        name: 'Test Deep Chapter',
      ),
    ],
    ayahs: ayahs,
    ayahWords: words,
    scripts: const [
      QuranScript(
        id: _scriptId,
        code: _scriptCode,
        displayName: 'Synthetic Deep-Scroll Test Script',
      ),
    ],
    scriptVariants: const [],
    mushafs: const [
      Mushaf(
        id: _mushafId,
        code: 'synthetic_deep_scroll_test',
        scriptId: _scriptId,
        pageCount: 2,
        linesPerPage: 5,
        qiraah: 'Test',
        edition: 'Test',
        renderingType: MushafRenderingType.unicodeText,
      ),
    ],
    mushafLines: mushafLines,
    mushafTokens: mushafTokens,
    navigationRanges: const [],
    metadata: DatasetMetadata(
      datasetVersion: 'deep-scroll-synthetic-test-fixture-1',
      contentHash: 'deadbeef-deep-scroll',
      importedAt: DateTime.utc(2024),
    ),
  );
}

void main() {
  testWidgets('switching from Mushaf mode to verse-by-verse while deep in an '
      'already-loaded chapter lands on the live Mushaf page\'s ayah, not the '
      "chapter's first ayah", (tester) async {
    // A phone-shaped viewport: the default 800x600 test surface is
    // wide/short enough to trip `MushafPager`'s two-page-spread
    // breakpoint, which would show pages 1 and 2 side by side from the
    // very start and make the swipe below a no-op.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, _buildDeepSurahPayload());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => _scriptCode),
          readerModePreferenceControllerProvider.overrideWith(
            () => _FixedReaderMode(ReaderMode.mushaf),
          ),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ReaderScreen(location: QuranLocation.surah(_deepSurah)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 1'), findsWidgets);

    // Swipe to page 2 -- the fixture's ayahs 31-60 -- mirroring the
    // existing swipe test's direction/gesture.
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.textContaining('Page 2'), findsWidgets);

    await tester.tap(find.byTooltip('Verse by verse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Fixed behavior: scrolled to the live page's own first ayah (2:31).
    expect(find.text('$_deepSurah:${_page1LastAyah + 1}'), findsWidgets);
    // The regression: silently landing back at the chapter's first ayah
    // instead, with the target ayah's own widget never built at all.
    expect(find.text('$_deepSurah:1'), findsNothing);
  });
}
