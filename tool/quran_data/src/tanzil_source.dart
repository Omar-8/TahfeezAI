// Parses Tanzil's Uthmani text file and quran-data.xml metadata file into a
// QuranDatasetPayload — the canonical Arabic Quran text layer.
//
// Kept deliberately separate from any Mushaf/QuranEnc concern: this file
// only ever produces surahs/surahLocalizations/ayahs/ayahWords/
// navigationRanges, never mushafs/mushafLines (those wait for the real QUL
// word dataset, per explicit product instruction — see
// docs/QURAN_DATA_PROVENANCE.md).
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart' as xml;
import 'package:crypto/crypto.dart';

import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

/// The canonical Uthmani text script Tahfeez ships, sourced from Tanzil.
///
/// `code` is deliberately `'uthmani'`, matching
/// `defaultQuranScriptCode` (`lib/quran/application/quran_script_code.dart`)
/// exactly — every reader/Mushaf/index session resolves words by that
/// default script code until a user picks a different one, and
/// `QuranRepository` returns zero words outright for a script code that
/// matches no installed [QuranScript] row, so this is not cosmetic: a
/// mismatch here would silently make every screen show no Quran text at all
/// despite a fully valid, imported dataset.
const kTanzilUthmaniScript = QuranScript(
  id: 1,
  code: 'uthmani',
  displayName: 'Uthmani (Tanzil)',
);

class TanzilSourceResult {
  const TanzilSourceResult({
    required this.payload,
    required this.textContentHash,
    required this.metadataContentHash,
    required this.textLicenseNotice,
  });

  final QuranDatasetPayload payload;
  final String textContentHash;
  final String metadataContentHash;
  final String textLicenseNotice;
}

/// Builds the canonical-text portion of the production dataset from Tanzil's
/// own files. [textFile] is Tanzil's `txt-2` (surah|ayah|text) export;
/// [metadataFile] is `quran-data.xml`.
TanzilSourceResult parseTanzilSource({
  required File textFile,
  required File metadataFile,
}) {
  final textBytes = textFile.readAsBytesSync();
  final metadataBytes = metadataFile.readAsBytesSync();
  final textContentHash = sha256.convert(textBytes).toString();
  final metadataContentHash = sha256.convert(metadataBytes).toString();

  final rawText = utf8.decode(textBytes);
  final licenseLines = rawText
      .split('\n')
      .where((l) => l.trim().startsWith('#'))
      .join('\n');

  final verseTexts = _parseVerseTexts(rawText);
  final doc = xml.XmlDocument.parse(utf8.decode(metadataBytes));
  final root = doc.rootElement;

  final surahMeta = _parseSurahMetadata(root);
  final surahs = <Surah>[];
  final surahLocalizations = <SurahLocalization>[];
  for (final s in surahMeta) {
    surahs.add(
      Surah(
        surahNo: s.index,
        ayahCount: s.ayahCount,
        revelationOrder: s.revelationOrder,
        rukusCount: s.rukusCount,
        revelationType: s.type == 'Meccan'
            ? RevelationType.meccan
            : RevelationType.medinan,
      ),
    );
    surahLocalizations.add(
      SurahLocalization(
        surahNo: s.index,
        languageCode: 'ar',
        name: s.arabicName,
      ),
    );
    surahLocalizations.add(
      SurahLocalization(
        surahNo: s.index,
        languageCode: 'en',
        name: s.transliteratedName,
        meaning: s.englishMeaning,
      ),
    );
  }
  final ayahCountBySurah = {for (final s in surahMeta) s.index: s.ayahCount};

  final sajdas = _parseSajdas(root);
  final juzBoundaries = _parseBoundaries(root, 'juzs', 'juz');
  final manzilBoundaries = _parseBoundaries(root, 'manzils', 'manzil');
  final rukuBoundaries = _parseBoundaries(root, 'rukus', 'ruku');
  final rubBoundaries = _parseBoundaries(root, 'hizbs', 'quarter');
  // Every 4th Rub (quarter) boundary is a Hizb boundary (4 quarters/Hizb).
  final hizbBoundaries = [
    for (var i = 0; i < rubBoundaries.length; i += 4) rubBoundaries[i],
  ];

  final globalOrder = _GlobalAyahOrder(ayahCountBySurah);

  final juzOf = _assignUnits(globalOrder, juzBoundaries);
  final hizbOf = _assignUnits(globalOrder, hizbBoundaries);
  final rubOf = _assignUnits(globalOrder, rubBoundaries);
  final manzilOf = _assignUnits(globalOrder, manzilBoundaries);
  final rukuOf = _assignUnits(globalOrder, rukuBoundaries);

  final ayahs = <Ayah>[];
  final ayahWords = <AyahWord>[];
  for (final surah in surahMeta) {
    for (var verseNo = 1; verseNo <= surah.ayahCount; verseNo++) {
      final key = (surah.index, verseNo);
      final id = surah.index * 1000 + verseNo;
      final sajdah = sajdas[key];
      ayahs.add(
        Ayah(
          id: id,
          chapterNo: surah.index,
          verseNo: verseNo,
          juzNo: juzOf[key]!,
          hizbNo: hizbOf[key]!,
          rubNo: rubOf[key]!,
          manzilNo: manzilOf[key]!,
          rukuNo: rukuOf[key]!,
          sajdah: sajdah,
        ),
      );

      var words = verseTexts[key]!;
      // Tanzil's plain-text export prepends the Bismillah to the first
      // ayah's text for every surah except At-Tawbah (surah 9) — for
      // Al-Fatiha (surah 1) that prefix *is* the whole of ayah 1, but for
      // every other surah it is a separate, non-numbered opening formula
      // that the Mushaf layout later renders as its own `basmallah` line,
      // never as part of ayah 1's word range. It must not be counted as
      // part of ayah 1's canonical words here, or word indices would never
      // line up with a real Mushaf word dataset, and ayah 1's word count
      // would silently include four words that are not part of verse 1.
      if (verseNo == 1 && surah.index != 1 && surah.index != 9) {
        words = words.length > 4 ? words.sublist(4) : words;
      }

      for (var i = 0; i < words.length; i++) {
        ayahWords.add(
          AyahWord(
            ayahId: id,
            scriptId: kTanzilUthmaniScript.id,
            wordIndex: i,
            text: words[i],
          ),
        );
      }
    }
  }

  final navigationRanges = <NavigationRange>[
    ..._toRanges(
      NavigationUnitType.juz,
      juzBoundaries,
      globalOrder,
      ayahCountBySurah,
    ),
    ..._toRanges(
      NavigationUnitType.hizb,
      hizbBoundaries,
      globalOrder,
      ayahCountBySurah,
    ),
    ..._toRanges(
      NavigationUnitType.rub,
      rubBoundaries,
      globalOrder,
      ayahCountBySurah,
    ),
    ..._toRanges(
      NavigationUnitType.manzil,
      manzilBoundaries,
      globalOrder,
      ayahCountBySurah,
    ),
  ];

  final payload = QuranDatasetPayload(
    surahs: surahs,
    surahLocalizations: surahLocalizations,
    ayahs: ayahs,
    ayahWords: ayahWords,
    scripts: [kTanzilUthmaniScript],
    scriptVariants: const [],
    // Mushaf layout deliberately withheld: no synthetic Mushaf data is ever
    // generated, and the real QUL word-id -> (ayah, wordIndex) mapping has
    // not yet been supplied. See docs/QURAN_DATA_PROVENANCE.md.
    mushafs: const <Mushaf>[],
    mushafLines: const <MushafLine>[],
    navigationRanges: navigationRanges,
    metadata: DatasetMetadata(
      datasetVersion: 'tanzil-uthmani-1.1',
      contentHash: textContentHash,
      importedAt: DateTime.now().toUtc(),
    ),
  );

  return TanzilSourceResult(
    payload: payload,
    textContentHash: textContentHash,
    metadataContentHash: metadataContentHash,
    textLicenseNotice: licenseLines,
  );
}

/// (chapterNo, verseNo) -> the verse's text split into whitespace tokens
/// (Tanzil's own word segmentation — one token per canonical word).
Map<(int, int), List<String>> _parseVerseTexts(String rawText) {
  final result = <(int, int), List<String>>{};
  for (final line in const LineSplitter().convert(rawText)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|');
    if (parts.length < 3) continue;
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);
    final text = parts.sublist(2).join('|');
    result[(surah, ayah)] = text.split(' ').where((t) => t.isNotEmpty).toList();
  }
  return result;
}

class _SurahMeta {
  const _SurahMeta({
    required this.index,
    required this.ayahCount,
    required this.arabicName,
    required this.transliteratedName,
    required this.englishMeaning,
    required this.type,
    required this.revelationOrder,
    required this.rukusCount,
  });

  final int index;
  final int ayahCount;
  final String arabicName;
  final String transliteratedName;
  final String englishMeaning;
  final String type;
  final int revelationOrder;
  final int rukusCount;
}

List<_SurahMeta> _parseSurahMetadata(xml.XmlElement root) {
  final suras = root.findElements('suras').first.findElements('sura');
  return suras
      .map(
        (s) => _SurahMeta(
          index: int.parse(s.getAttribute('index')!),
          ayahCount: int.parse(s.getAttribute('ayas')!),
          arabicName: s.getAttribute('name')!,
          transliteratedName: s.getAttribute('tname')!,
          englishMeaning: s.getAttribute('ename')!,
          type: s.getAttribute('type')!,
          revelationOrder: int.parse(s.getAttribute('order')!),
          rukusCount: int.parse(s.getAttribute('rukus')!),
        ),
      )
      .toList();
}

Map<(int, int), SajdahType> _parseSajdas(xml.XmlElement root) {
  final sajdas = root.findElements('sajdas').first.findElements('sajda');
  final result = <(int, int), SajdahType>{};
  for (final s in sajdas) {
    final surah = int.parse(s.getAttribute('sura')!);
    final ayah = int.parse(s.getAttribute('aya')!);
    final type = s.getAttribute('type') == 'obligatory'
        ? SajdahType.obligatory
        : SajdahType.recommended;
    result[(surah, ayah)] = type;
  }
  return result;
}

/// One navigation-unit boundary: unit [index] begins at ([surah], [ayah]).
class _Boundary {
  const _Boundary(this.index, this.surah, this.ayah);
  final int index;
  final int surah;
  final int ayah;
}

List<_Boundary> _parseBoundaries(
  xml.XmlElement root,
  String parentTag,
  String childTag,
) {
  final elements = root.findElements(parentTag).first.findElements(childTag);
  return elements
      .map(
        (e) => _Boundary(
          int.parse(e.getAttribute('index')!),
          int.parse(e.getAttribute('sura')!),
          int.parse(e.getAttribute('aya')!),
        ),
      )
      .toList();
}

/// A total ordering over every (surah, ayah) in the Quran, so a boundary can
/// be compared against another via a single integer position.
class _GlobalAyahOrder {
  _GlobalAyahOrder(Map<int, int> ayahCountBySurah) {
    var position = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final count = ayahCountBySurah[surah]!;
      for (var ayah = 1; ayah <= count; ayah++) {
        _positions[(surah, ayah)] = position;
        position++;
      }
    }
  }

  final Map<(int, int), int> _positions = {};

  int positionOf(int surah, int ayah) => _positions[(surah, ayah)]!;
}

/// Assigns every (surah, ayah) to the navigation unit number whose boundary
/// most recently started at or before it.
Map<(int, int), int> _assignUnits(
  _GlobalAyahOrder order,
  List<_Boundary> boundaries,
) {
  final sorted = [...boundaries]
    ..sort(
      (a, b) => order
          .positionOf(a.surah, a.ayah)
          .compareTo(order.positionOf(b.surah, b.ayah)),
    );

  final result = <(int, int), int>{};
  var boundaryIdx = 0;
  var currentUnit = sorted.first.index;
  for (var surah = 1; surah <= 114; surah++) {
    var ayah = 1;
    while (order._positions.containsKey((surah, ayah))) {
      while (boundaryIdx + 1 < sorted.length &&
          order.positionOf(
                sorted[boundaryIdx + 1].surah,
                sorted[boundaryIdx + 1].ayah,
              ) <=
              order.positionOf(surah, ayah)) {
        boundaryIdx++;
        currentUnit = sorted[boundaryIdx].index;
      }
      result[(surah, ayah)] = currentUnit;
      ayah++;
    }
  }
  return result;
}

Iterable<NavigationRange> _toRanges(
  NavigationUnitType type,
  List<_Boundary> boundaries,
  _GlobalAyahOrder order,
  Map<int, int> ayahCountBySurah,
) sync* {
  final sorted = [...boundaries]
    ..sort(
      (a, b) => order
          .positionOf(a.surah, a.ayah)
          .compareTo(order.positionOf(b.surah, b.ayah)),
    );

  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i];
    final int endSurah;
    final int endAyah;
    if (i + 1 < sorted.length) {
      final next = sorted[i + 1];
      if (next.ayah > 1) {
        endSurah = next.surah;
        endAyah = next.ayah - 1;
      } else {
        endSurah = next.surah - 1;
        endAyah = ayahCountBySurah[endSurah]!;
      }
    } else {
      endSurah = 114;
      endAyah = ayahCountBySurah[114]!;
    }

    for (var surah = start.surah; surah <= endSurah; surah++) {
      final rangeStart = surah == start.surah ? start.ayah : 1;
      final rangeEnd = surah == endSurah ? endAyah : ayahCountBySurah[surah]!;
      yield NavigationRange(
        type: type,
        unitNo: start.index,
        surahNo: surah,
        startAyahNo: rangeStart,
        endAyahNo: rangeEnd,
      );
    }
  }
}
