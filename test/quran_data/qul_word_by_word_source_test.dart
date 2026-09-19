// Validates the REAL, user-provided QUL KFGQPC V2 word-by-word database
// (vendored at tool/quran_data/sources/qpc-v2-word-by-word.db.zip) against
// the REAL bundled canonical dataset, end to end through
// MushafTokenClassifier. This is the concrete evidence behind the
// investigation reported in docs/QURAN_DATA_PROVENANCE.md: exactly one
// ayah-end marker token per ayah except 37:130 (which has none), and zero
// unclassifiable tokens. Never uses synthetic data for either side of the
// comparison.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_token_classifier.dart';

import '../../tool/quran_data/src/mushaf_wbw_source.dart';

void main() {
  final zip = File(
    p.join('tool', 'quran_data', 'sources', 'qpc-v2-word-by-word.db.zip'),
  );

  test('the vendored QUL word-by-word source file is present', () {
    expect(
      zip.existsSync(),
      isTrue,
      reason: 'tool/quran_data/sources/qpc-v2-word-by-word.db.zip is missing',
    );
  });

  test('classifying the real word-by-word data against the real canonical '
      'dataset matches the documented investigation exactly', () async {
    final tempDir = Directory.systemTemp.createTempSync('qul_wbw_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final result = Process.runSync('unzip', [
      '-o',
      zip.path,
      '-d',
      tempDir.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final source = QulKfgqpcV2WordByWordSource(
      File(p.join(tempDir.path, 'qpc-v2.db')),
    );
    final info = source.readInfo();
    expect(info.tokenCount, 83668);

    final rawTokens = await source.loadRawTokens();
    expect(rawTokens, hasLength(83668));
    // The classifier's per-ayah decision depends on token order matching
    // (surah, ayah, word-position) order — verified separately by the
    // audit; here we just confirm the source itself hands them over
    // already sorted by id.
    for (var i = 1; i < rawTokens.length; i++) {
      expect(rawTokens[i].sourceTokenId, rawTokens[i - 1].sourceTokenId + 1);
    }

    final payload = quranDatasetPayloadFromJson(
      jsonDecode(File('assets/quran/quran_dataset.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final canonicalCounts = <int, int>{};
    for (final word in payload.ayahWords) {
      canonicalCounts[word.ayahId] = (canonicalCounts[word.ayahId] ?? 0) + 1;
    }

    const classifier = MushafTokenClassifier();
    final classified = classifier.classify(
      mushafId: 1,
      rawTokens: rawTokens,
      canonicalWordCountByAyahId: canonicalCounts,
    );

    // Zero unknown/otherMarker tokens, and exactly one warning — for the
    // real ayah 37:130 (the one true exception to the ayah-marker rule)
    // — only if it doesn't cleanly match, which it does (0 warnings
    // expected).
    expect(
      classified.warnings,
      isEmpty,
      reason: classified.warnings.join('\n'),
    );

    final byType = <MushafTokenType, int>{};
    for (final t in classified.tokens) {
      byType[t.tokenType] = (byType[t.tokenType] ?? 0) + 1;
    }
    expect(byType[MushafTokenType.unknown] ?? 0, 0);
    expect(byType[MushafTokenType.otherMarker] ?? 0, 0);
    expect(byType[MushafTokenType.ayahMarker], 6235);
    expect(byType[MushafTokenType.quranWord], 77433);

    // 37:130 is the one ayah with no marker — all 4 of its tokens must
    // be quranWord.
    final tawbahException = classified.tokens
        .where((t) => t.surahNumber == 37 && t.ayahNumber == 130)
        .toList();
    expect(tawbahException, hasLength(4));
    expect(
      tawbahException.every((t) => t.tokenType == MushafTokenType.quranWord),
      isTrue,
    );

    // Every quranWord token's canonical mapping must resolve to a real
    // AyahWord — never a fabricated index.
    final canonicalKeys = {
      for (final w in payload.ayahWords) (w.ayahId, w.wordIndex),
    };
    for (final t in classified.tokens) {
      if (t.tokenType == MushafTokenType.quranWord) {
        expect(
          canonicalKeys.contains((t.canonicalAyahId, t.canonicalWordIndex)),
          isTrue,
          reason:
              'token ${t.sourceTokenId} (${t.surahNumber}:${t.ayahNumber}) '
              'claims canonical (${t.canonicalAyahId}, ${t.canonicalWordIndex}) '
              'which does not exist',
        );
      } else {
        expect(t.canonicalAyahId, isNull);
        expect(t.canonicalWordIndex, isNull);
      }
    }
  });
}
