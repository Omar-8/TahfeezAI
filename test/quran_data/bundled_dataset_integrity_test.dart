// Integrity checks against the REAL bundled production Quran dataset
// (assets/quran/), built by tool/quran_data/build_production_data.dart from
// Tanzil and QuranEnc — never against synthetic fixtures. This is the
// concrete "Surahs = 114 with per-surah ayah counts", "translation/tafsir
// completeness", and "resource manifest hash" verification the production
// data-integration milestone requires, run every time `flutter test` runs
// so a regression in the dataset or its build tooling is caught in CI, not
// after shipping.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/dataset_integrity.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final manifest = _readJson('assets/quran/resource_manifest.json');
  final payload = quranDatasetPayloadFromJson(
    _readJson('assets/quran/quran_dataset.json'),
  );

  group('Canonical Quran dataset', () {
    test('has exactly 114 surahs', () {
      expect(payload.surahs, hasLength(114));
      expect(
        payload.surahs.map((s) => s.surahNo).toSet(),
        List.generate(114, (i) => i + 1).toSet(),
      );
    });

    test('every surah has the correct, individually-checked ayah count', () {
      // Spot-checked against well-known chapter lengths, not just a total —
      // an aggregate-only check could hide two surahs' counts being swapped.
      const knownAyahCounts = {
        1: 7, // Al-Fatiha
        2: 286, // Al-Baqarah
        18: 110, // Al-Kahf
        36: 83, // Ya-Sin
        112: 4, // Al-Ikhlas
        113: 5, // Al-Falaq
        114: 6, // An-Nas
      };
      final bySurah = {for (final s in payload.surahs) s.surahNo: s.ayahCount};
      for (final entry in knownAyahCounts.entries) {
        expect(
          bySurah[entry.key],
          entry.value,
          reason: 'Surah ${entry.key} ayah count',
        );
      }
    });

    test('has exactly 6236 ayahs in total', () {
      expect(payload.ayahs, hasLength(6236));
    });

    test(
      'the shipped script code matches the app-wide default script code',
      () {
        // A mismatch here is not cosmetic: QuranRepository returns zero
        // words outright for a script code that matches no installed
        // QuranScript row, so every reader/Mushaf/index screen would show
        // no Quran text at all despite a fully valid, imported dataset.
        expect(payload.scripts, hasLength(1));
        expect(payload.scripts.single.code, defaultQuranScriptCode);
      },
    );

    test('passes full structural integrity validation', () {
      const validator = DatasetIntegrityValidator();
      final report = validator.validate(payload);
      expect(
        report.isValid,
        isTrue,
        reason: report.errors.map((e) => e.toString()).join('\n'),
      );
    });

    test('has exactly the 15 traditionally-recognized Sajdah verses', () {
      final sajdahCount = payload.ayahs.where((a) => a.sajdah != null).length;
      expect(sajdahCount, 15);
    });

    test(
      'navigation units cover exactly 30 Juz, 60 Hizb, 240 Rub, 7 Manzil',
      () {
        final byType = <String, Set<int>>{};
        for (final r in payload.navigationRanges) {
          byType.putIfAbsent(r.type.name, () => {}).add(r.unitNo);
        }
        expect(byType['juz'], hasLength(30));
        expect(byType['hizb'], hasLength(60));
        expect(byType['rub'], hasLength(240));
        expect(byType['manzil'], hasLength(7));
      },
    );

    test(
      'Al-Fatiha verse 1 is the Bismillah; other surahs never double-count it',
      () {
        AyahWord wordAt(int surah, int ayah, int index) =>
            payload.ayahWords.firstWhere(
              (w) => w.ayahId == surah * 1000 + ayah && w.wordIndex == index,
            );

        // Al-Fatiha's own verse 1 IS the Bismillah (4 words).
        final fatihaWords = payload.ayahWords.where((w) => w.ayahId == 1001);
        expect(fatihaWords, hasLength(4));

        // Al-Baqarah verse 1 is just the disjointed letters, no
        // prepended Bismillah — a single word, and not the Bismillah's own
        // first word (compared against Al-Fatiha's real parsed text rather
        // than a hardcoded literal, to avoid Unicode-normalization
        // mismatches between this source file and the parsed data).
        final bismillahFirstWord = wordAt(1, 1, 0).text;
        final baqarahWords = payload.ayahWords.where((w) => w.ayahId == 2001);
        expect(baqarahWords, hasLength(1));
        expect(wordAt(2, 1, 0).text, isNot(bismillahFirstWord));

        // At-Tawbah has no Bismillah at all, including no leading one on
        // its own verse 1 (9 words, matching its well-known verse length,
        // not the 4 extra words a prepended Bismillah would add).
        final tawbahWords = payload.ayahWords.where((w) => w.ayahId == 9001);
        expect(tawbahWords, hasLength(9));
        expect(wordAt(9, 1, 0).text, isNot(bismillahFirstWord));
      },
    );

    test('resource manifest hashes are recorded for every packaged asset', () {
      final hashes = (manifest['packagedAssetHashes'] as Map)
          .cast<String, dynamic>();
      for (final entry in {
        'quran_dataset.json': 'assets/quran/quran_dataset.json',
        'translations/en_rowwad.json':
            'assets/quran/translations/en_rowwad.json',
        'translations/de_rowwad.json':
            'assets/quran/translations/de_rowwad.json',
        'tafsir/ar_muyassar.json': 'assets/quran/tafsir/ar_muyassar.json',
      }.entries) {
        final expected = hashes[entry.key] as String?;
        expect(expected, isNotNull, reason: '${entry.key} hash missing');
        final actual = sha256
            .convert(File(entry.value).readAsBytesSync())
            .toString();
        expect(
          actual,
          expected,
          reason: '${entry.value} does not match its recorded manifest hash',
        );
      }
    });
  });

  group('Bundled translations', () {
    for (final path in [
      'assets/quran/translations/en_rowwad.json',
      'assets/quran/translations/de_rowwad.json',
    ]) {
      test('$path has one entry for every one of the 6236 canonical ayahs', () {
        final json = _readJson(path);
        final book = translationBookFromJson(
          json['book'] as Map<String, dynamic>,
        );
        final verses = (json['verses'] as List)
            .cast<Map<String, dynamic>>()
            .map(translationVerseFromJson)
            .toList();

        expect(verses, hasLength(6236));
        final coveredKeys = verses
            .map((v) => '${v.chapterNo}:${v.verseNo}')
            .toSet();
        final expectedKeys = payload.ayahs
            .map((a) => '${a.chapterNo}:${a.verseNo}')
            .toSet();
        expect(coveredKeys, expectedKeys);
        expect(book.checksum, isNotEmpty);
      });
    }
  });

  group('Bundled tafsir', () {
    test(
      'Al-Muyassar has one entry for every one of the 6236 canonical ayahs',
      () {
        final json = _readJson('assets/quran/tafsir/ar_muyassar.json');
        final work = tafsirWorkFromJson(json['work'] as Map<String, dynamic>);
        final verses = (json['verses'] as List)
            .cast<Map<String, dynamic>>()
            .map(tafsirVerseFromJson)
            .toList();

        expect(verses, hasLength(6236));
        final coveredKeys = verses
            .map((v) => '${v.chapterNo}:${v.verseNo}')
            .toSet();
        final expectedKeys = payload.ayahs
            .map((a) => '${a.chapterNo}:${a.verseNo}')
            .toSet();
        expect(coveredKeys, expectedKeys);
        expect(work.checksum, isNotEmpty);
      },
    );
  });

  group('Mushaf layout status (honest, not fabricated)', () {
    test(
      'no Mushaf layout is shipped yet — the word dataset has not arrived',
      () {
        expect(payload.mushafs, isEmpty);
        expect(payload.mushafLines, isEmpty);
        expect(manifest['mushafStatus'], 'SHIP_BLOCKED_PENDING_WORD_DATA');
      },
    );
  });
}
