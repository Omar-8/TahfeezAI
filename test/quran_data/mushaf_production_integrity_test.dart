// Integrity checks against the REAL generated production Mushaf dataset
// (assets/quran/mushaf/kfgqpc_v2.json), built by
// tool/quran_data/build_production_data.dart from the real, vendored QUL
// layout and word-by-word databases — never against synthetic fixtures.
// This is the concrete "test the generated production asset, not just the
// importer's source files" verification docs/QURAN_DATA_PROVENANCE.md §7c
// and this milestone require.
//
// This asset is not yet a Flutter-bundled asset (see the release-gate note
// in tool/quran_data/build_production_data.dart), so it is read directly
// from disk here, the same way the other qul_*_test.dart files validate
// real vendored/generated files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final json = _readJson('assets/quran/mushaf/kfgqpc_v2.json');
  final mushaf = json['mushaf'] as Map<String, dynamic>;
  final lines = (json['mushafLines'] as List)
      .cast<Map<String, dynamic>>()
      .toList();
  final tokens = (json['mushafTokens'] as List)
      .cast<Map<String, dynamic>>()
      .map(mushafTokenFromJson)
      .toList();

  final canonicalPayload = quranDatasetPayloadFromJson(
    jsonDecode(File('assets/quran/quran_dataset.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final canonicalAyahWordKeys = {
    for (final w in canonicalPayload.ayahWords) (w.ayahId, w.wordIndex),
  };

  group('Mushaf metadata', () {
    test('declares the expected KFGQPC V2 edition', () {
      expect(mushaf['pageCount'], 604);
      expect(mushaf['linesPerPage'], 15);
      expect(mushaf['code'], 'kfgqpc_v2');
      expect(mushaf['qiraah'], 'Hafs');
      expect(mushaf['renderingType'], 'pageSpecificGlyphFont');
    });
  });

  group('Mushaf lines', () {
    test('covers exactly pages 1..604 with no gaps', () {
      final pages = lines.map((l) => l['pageNumber'] as int).toSet();
      expect(pages, hasLength(604));
      expect(pages, List.generate(604, (i) => i + 1).toSet());
    });

    test('pages 1-2 have 8 lines, every other page has 15', () {
      final countByPage = <int, int>{};
      for (final l in lines) {
        final p = l['pageNumber'] as int;
        countByPage[p] = (countByPage[p] ?? 0) + 1;
      }
      expect(countByPage[1], 8);
      expect(countByPage[2], 8);
      for (var p = 3; p <= 604; p++) {
        expect(countByPage[p], 15, reason: 'page $p');
      }
    });

    test(
      'every quranText line\'s token range resolves and is not reversed',
      () {
        final tokenIds = tokens.map((t) => t.sourceTokenId).toSet();
        for (final l in lines) {
          if (l['lineType'] != 'quranText') continue;
          final first = l['firstTokenId'] as int?;
          final last = l['lastTokenId'] as int?;
          expect(
            first,
            isNotNull,
            reason: '${l['pageNumber']}:${l['lineNumber']}',
          );
          expect(
            last,
            isNotNull,
            reason: '${l['pageNumber']}:${l['lineNumber']}',
          );
          expect(tokenIds.contains(first), isTrue);
          expect(tokenIds.contains(last), isTrue);
          expect(first! <= last!, isTrue, reason: 'range runs backward');
        }
      },
    );

    test('all 604 pages can be materialized (every page has >=1 line)', () {
      final countByPage = <int, int>{};
      for (final l in lines) {
        final p = l['pageNumber'] as int;
        countByPage[p] = (countByPage[p] ?? 0) + 1;
      }
      for (var p = 1; p <= 604; p++) {
        expect(countByPage[p], greaterThan(0), reason: 'page $p');
      }
    });
  });

  group('Mushaf tokens', () {
    test('has exactly 83,668 tokens with no duplicate source token ids', () {
      expect(tokens, hasLength(83668));
      final ids = tokens.map((t) => t.sourceTokenId).toSet();
      expect(ids, hasLength(83668));
    });

    test('has exactly the documented type breakdown', () {
      final byType = <String, int>{};
      for (final t in tokens) {
        byType[t.tokenType.name] = (byType[t.tokenType.name] ?? 0) + 1;
      }
      expect(byType['quranWord'], 77433);
      expect(byType['ayahMarker'], 6235);
      expect(byType['otherMarker'] ?? 0, 0);
      expect(byType['unknown'] ?? 0, 0);
    });

    test('represents all 6236 canonical ayahs', () {
      final ayahKeys = tokens
          .map((t) => '${t.surahNumber}:${t.ayahNumber}')
          .toSet();
      expect(ayahKeys, hasLength(6236));
    });

    test('ayah 37:130 is the sole ayah with no ayahMarker token', () {
      final byAyah = <String, List<String>>{};
      for (final t in tokens) {
        final key = '${t.surahNumber}:${t.ayahNumber}';
        byAyah.putIfAbsent(key, () => []).add(t.tokenType.name);
      }
      final withoutMarker = byAyah.entries
          .where((e) => !e.value.contains('ayahMarker'))
          .map((e) => e.key)
          .toList();
      expect(withoutMarker, ['37:130']);
    });

    test(
      'every quranWord token\'s canonical mapping resolves to a real AyahWord',
      () {
        for (final t in tokens) {
          if (t.tokenType.name != 'quranWord') continue;
          expect(t.canonicalAyahId, isNotNull);
          expect(t.canonicalWordIndex, isNotNull);
          expect(
            canonicalAyahWordKeys.contains((
              t.canonicalAyahId,
              t.canonicalWordIndex,
            )),
            isTrue,
            reason: 'token ${t.sourceTokenId}',
          );
        }
      },
    );

    test('no marker token carries a fabricated canonical mapping', () {
      for (final t in tokens) {
        if (t.tokenType.name == 'quranWord') continue;
        expect(t.canonicalAyahId, isNull, reason: 'token ${t.sourceTokenId}');
        expect(
          t.canonicalWordIndex,
          isNull,
          reason: 'token ${t.sourceTokenId}',
        );
      }
    });
  });
}
