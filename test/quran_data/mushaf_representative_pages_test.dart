// Materializes representative pages from the REAL generated production
// Mushaf dataset (assets/quran/mushaf/kfgqpc_v2.json) through the actual
// repository/import stack (QuranDatasetImporter -> DriftQuranRepository),
// the same path the real app's Mushaf reader will eventually use — not a
// bare JSON inspection. Reports line count, line types, token count, and
// first/last Quran location for page 1, page 2, a page with a real Surah
// transition, a middle page, and page 604, per this milestone's explicit
// representative-page validation requirement.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

void main() {
  late DriftQuranRepository repo;
  const mushafId = 1;

  setUpAll(() async {
    final canonical = quranDatasetPayloadFromJson(
      jsonDecode(File('assets/quran/quran_dataset.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final mushafJson = jsonDecode(
      File('assets/quran/mushaf/kfgqpc_v2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final mushaf = mushafFromJson(mushafJson['mushaf'] as Map<String, dynamic>);
    final lines = (mushafJson['mushafLines'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafLineFromJson)
        .toList();
    final tokens = (mushafJson['mushafTokens'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafTokenFromJson)
        .toList();

    final fullPayload = QuranDatasetPayload(
      surahs: canonical.surahs,
      surahLocalizations: canonical.surahLocalizations,
      ayahs: canonical.ayahs,
      ayahWords: canonical.ayahWords,
      scripts: canonical.scripts,
      scriptVariants: canonical.scriptVariants,
      mushafs: [mushaf],
      mushafLines: lines,
      mushafTokens: tokens,
      navigationRanges: canonical.navigationRanges,
      metadata: canonical.metadata,
    );

    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, fullPayload);
    repo = DriftQuranRepository(db);
  });

  Future<void> reportPage(int pageNumber, {String? note}) async {
    final page = await repo.getPage(mushafId: mushafId, pageNumber: pageNumber);
    expect(page, isNotNull, reason: 'page $pageNumber must materialize');

    final tokens = await repo.getPageTokens(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    final quranWordTokens = tokens
        .where((t) => t.tokenType == MushafTokenType.quranWord)
        .toList();

    // ignore: avoid_print
    print(
      'Page $pageNumber${note != null ? ' ($note)' : ''}: '
      '${page!.lines.length} lines '
      '[${page.lines.map((l) => l.lineType.name).toSet().join(', ')}], '
      '${tokens.length} tokens, '
      'first=${quranWordTokens.isEmpty ? '-' : '${quranWordTokens.first.surahNumber}:${quranWordTokens.first.ayahNumber}:${quranWordTokens.first.sourceWordPosition}'}, '
      'last=${quranWordTokens.isEmpty ? '-' : '${quranWordTokens.last.surahNumber}:${quranWordTokens.last.ayahNumber}:${quranWordTokens.last.sourceWordPosition}'}',
    );

    expect(page.lines, isNotEmpty);
    // Every line resolves to real tokens (or none, for header/bismillah).
    for (final line in page.lines) {
      final lineTokens = await repo.getLineTokens(line);
      if (line.lineType.name == 'quranText') {
        expect(lineTokens, isNotEmpty, reason: 'line ${line.lineNumber}');
      }
    }
  }

  test('page 1 — opening of the Mushaf (Al-Fatiha)', () async {
    await reportPage(1);
    final page = await repo.getPage(mushafId: mushafId, pageNumber: 1);
    expect(page!.lines, hasLength(8));
    expect(page.lines.first.lineType.name, 'surahHeader');
    expect(page.lines.first.surahNo, 1);
  });

  test('page 2 — continues Al-Fatiha / begins Al-Baqarah', () async {
    await reportPage(2);
    final page = await repo.getPage(mushafId: mushafId, pageNumber: 2);
    expect(page!.lines, hasLength(8));
  });

  test(
    'page 106 — a real Surah transition (An-Nisa ends, Al-Maidah begins)',
    () async {
      await reportPage(106, note: 'Surah transition');
      final page = await repo.getPage(mushafId: mushafId, pageNumber: 106);
      expect(page!.lines, hasLength(15));
      final headerLine = page.lines.firstWhere(
        (l) => l.lineType.name == 'surahHeader',
      );
      expect(headerLine.surahNo, 5);
      expect(headerLine.lineNumber, greaterThan(1));
    },
  );

  test('page 302 — a representative middle page', () async {
    await reportPage(302, note: 'middle page');
    final page = await repo.getPage(mushafId: mushafId, pageNumber: 302);
    expect(page!.lines, hasLength(15));
  });

  test('page 604 — the final page of the Mushaf', () async {
    await reportPage(604);
    final page = await repo.getPage(mushafId: mushafId, pageNumber: 604);
    expect(page!.lines, hasLength(15));
    final tokens = await repo.getPageTokens(
      mushafId: mushafId,
      pageNumber: 604,
    );
    final lastQuranWord = tokens.lastWhere(
      (t) => t.tokenType == MushafTokenType.quranWord,
    );
    expect(lastQuranWord.surahNumber, 114);
    expect(lastQuranWord.ayahNumber, 6);
  });

  test(
    'every ayah\'s page in one pass agrees with the one-ayah lookup',
    () async {
      final pages = await repo.getAyahPages(mushafId: mushafId);
      expect(pages, hasLength(6236));
      expect(
        (pages[1001], pages[2001], pages[2255], pages[114006]),
        (1, 2, 42, 604),
      );
      for (final ayah in [1007, 2005, 5001, 18001, 36001, 67001, 112001]) {
        expect(
          pages[ayah],
          await repo.getPageForAyah(mushafId: mushafId, ayahId: ayah),
          reason: '$ayah',
        );
      }
    },
  );
}
