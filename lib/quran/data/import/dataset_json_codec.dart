// Hand-written JSON <-> domain-model conversion for everything the bundled
// production dataset ships. Deliberately not code-generated: these types
// live in lib/quran/domain and are Flutter/Drift-free, and the mapping is
// small and stable enough that a generator would add more ceremony than it
// removes. Shared by tool/quran_data/build_production_data.dart (writes
// assets/quran/*.json at build time) and bundled_dataset_seeder.dart (reads
// them back at app startup) — one codec, so the two can never drift apart.
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/dataset_metadata.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';
import 'package:tahfeez_ai/quran/domain/models/script_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/tafsir_models.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

Map<String, dynamic> surahToJson(Surah s) => {
  'surahNo': s.surahNo,
  'ayahCount': s.ayahCount,
  'revelationOrder': s.revelationOrder,
  'rukusCount': s.rukusCount,
  'revelationType': s.revelationType.name,
};

Map<String, dynamic> surahLocalizationToJson(SurahLocalization l) => {
  'surahNo': l.surahNo,
  'languageCode': l.languageCode,
  'name': l.name,
  if (l.meaning != null) 'meaning': l.meaning,
};

Map<String, dynamic> ayahToJson(Ayah a) => {
  'id': a.id,
  'chapterNo': a.chapterNo,
  'verseNo': a.verseNo,
  'juzNo': a.juzNo,
  'hizbNo': a.hizbNo,
  'rubNo': a.rubNo,
  'manzilNo': a.manzilNo,
  'rukuNo': a.rukuNo,
  if (a.sajdah != null) 'sajdah': a.sajdah!.name,
};

Map<String, dynamic> ayahWordToJson(AyahWord w) => {
  'ayahId': w.ayahId,
  'scriptId': w.scriptId,
  'wordIndex': w.wordIndex,
  'text': w.text,
};

Map<String, dynamic> scriptToJson(QuranScript s) => {
  'id': s.id,
  'code': s.code,
  'displayName': s.displayName,
};

Map<String, dynamic> scriptVariantToJson(QuranScriptVariant v) => {
  'id': v.id,
  'scriptId': v.scriptId,
  'code': v.code,
  'displayName': v.displayName,
};

Map<String, dynamic> mushafToJson(Mushaf m) => {
  'id': m.id,
  'code': m.code,
  'scriptId': m.scriptId,
  if (m.scriptVariantId != null) 'scriptVariantId': m.scriptVariantId,
  'pageCount': m.pageCount,
  'linesPerPage': m.linesPerPage,
  'qiraah': m.qiraah,
  'edition': m.edition,
  'renderingType': m.renderingType.name,
};

Mushaf mushafFromJson(Map<String, dynamic> j) => Mushaf(
  id: j['id'] as int,
  code: j['code'] as String,
  scriptId: j['scriptId'] as int,
  scriptVariantId: j['scriptVariantId'] as int?,
  pageCount: j['pageCount'] as int,
  linesPerPage: j['linesPerPage'] as int,
  qiraah: j['qiraah'] as String,
  edition: j['edition'] as String,
  renderingType: MushafRenderingType.values.byName(
    j['renderingType'] as String,
  ),
);

Map<String, dynamic> mushafLineToJson(MushafLine l) => {
  'mushafId': l.mushafId,
  'pageNumber': l.pageNumber,
  'lineNumber': l.lineNumber,
  'lineType': l.lineType.name,
  'isCentered': l.isCentered,
  if (l.firstTokenId != null) 'firstTokenId': l.firstTokenId,
  if (l.lastTokenId != null) 'lastTokenId': l.lastTokenId,
  if (l.surahNo != null) 'surahNo': l.surahNo,
};

MushafLine mushafLineFromJson(Map<String, dynamic> j) => MushafLine(
  mushafId: j['mushafId'] as int,
  pageNumber: j['pageNumber'] as int,
  lineNumber: j['lineNumber'] as int,
  lineType: MushafLineType.values.byName(j['lineType'] as String),
  isCentered: j['isCentered'] as bool,
  firstTokenId: j['firstTokenId'] as int?,
  lastTokenId: j['lastTokenId'] as int?,
  surahNo: j['surahNo'] as int?,
);

Map<String, dynamic> mushafTokenToJson(MushafToken t) => {
  'mushafId': t.mushafId,
  'sourceTokenId': t.sourceTokenId,
  'sequenceIndex': t.sequenceIndex,
  'tokenType': t.tokenType.name,
  'displayText': t.displayText,
  if (t.surahNumber != null) 'surahNumber': t.surahNumber,
  if (t.ayahNumber != null) 'ayahNumber': t.ayahNumber,
  if (t.sourceWordPosition != null) 'sourceWordPosition': t.sourceWordPosition,
  if (t.canonicalWordIndex != null) 'canonicalWordIndex': t.canonicalWordIndex,
  if (t.canonicalAyahId != null) 'canonicalAyahId': t.canonicalAyahId,
};

MushafToken mushafTokenFromJson(Map<String, dynamic> j) => MushafToken(
  mushafId: j['mushafId'] as int,
  sourceTokenId: j['sourceTokenId'] as int,
  sequenceIndex: j['sequenceIndex'] as int,
  tokenType: MushafTokenType.values.byName(j['tokenType'] as String),
  displayText: j['displayText'] as String,
  surahNumber: j['surahNumber'] as int?,
  ayahNumber: j['ayahNumber'] as int?,
  sourceWordPosition: j['sourceWordPosition'] as int?,
  canonicalWordIndex: j['canonicalWordIndex'] as int?,
  canonicalAyahId: j['canonicalAyahId'] as int?,
);

Map<String, dynamic> navigationRangeToJson(NavigationRange r) => {
  'type': r.type.name,
  'unitNo': r.unitNo,
  'surahNo': r.surahNo,
  'startAyahNo': r.startAyahNo,
  'endAyahNo': r.endAyahNo,
};

Map<String, dynamic> datasetMetadataToJson(DatasetMetadata m) => {
  'datasetVersion': m.datasetVersion,
  'contentHash': m.contentHash,
  'importedAt': m.importedAt.toIso8601String(),
};

Map<String, dynamic> quranDatasetPayloadToJson(QuranDatasetPayload p) => {
  'surahs': p.surahs.map(surahToJson).toList(),
  'surahLocalizations': p.surahLocalizations
      .map(surahLocalizationToJson)
      .toList(),
  'ayahs': p.ayahs.map(ayahToJson).toList(),
  'ayahWords': p.ayahWords.map(ayahWordToJson).toList(),
  'scripts': p.scripts.map(scriptToJson).toList(),
  'scriptVariants': p.scriptVariants.map(scriptVariantToJson).toList(),
  'mushafs': p.mushafs.map(mushafToJson).toList(),
  'mushafLines': p.mushafLines.map(mushafLineToJson).toList(),
  'mushafTokens': p.mushafTokens.map(mushafTokenToJson).toList(),
  'navigationRanges': p.navigationRanges.map(navigationRangeToJson).toList(),
  'metadata': datasetMetadataToJson(p.metadata),
};

QuranDatasetPayload quranDatasetPayloadFromJson(Map<String, dynamic> json) {
  return QuranDatasetPayload(
    surahs: (json['surahs'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => Surah(
            surahNo: j['surahNo'] as int,
            ayahCount: j['ayahCount'] as int,
            revelationOrder: j['revelationOrder'] as int,
            rukusCount: j['rukusCount'] as int,
            revelationType: RevelationType.values.byName(
              j['revelationType'] as String,
            ),
          ),
        )
        .toList(),
    surahLocalizations: (json['surahLocalizations'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => SurahLocalization(
            surahNo: j['surahNo'] as int,
            languageCode: j['languageCode'] as String,
            name: j['name'] as String,
            meaning: j['meaning'] as String?,
          ),
        )
        .toList(),
    ayahs: (json['ayahs'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => Ayah(
            id: j['id'] as int,
            chapterNo: j['chapterNo'] as int,
            verseNo: j['verseNo'] as int,
            juzNo: j['juzNo'] as int,
            hizbNo: j['hizbNo'] as int,
            rubNo: j['rubNo'] as int,
            manzilNo: j['manzilNo'] as int,
            rukuNo: j['rukuNo'] as int,
            sajdah: j['sajdah'] == null
                ? null
                : SajdahType.values.byName(j['sajdah'] as String),
          ),
        )
        .toList(),
    ayahWords: (json['ayahWords'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => AyahWord(
            ayahId: j['ayahId'] as int,
            scriptId: j['scriptId'] as int,
            wordIndex: j['wordIndex'] as int,
            text: j['text'] as String,
          ),
        )
        .toList(),
    scripts: (json['scripts'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => QuranScript(
            id: j['id'] as int,
            code: j['code'] as String,
            displayName: j['displayName'] as String,
          ),
        )
        .toList(),
    scriptVariants: (json['scriptVariants'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => QuranScriptVariant(
            id: j['id'] as int,
            scriptId: j['scriptId'] as int,
            code: j['code'] as String,
            displayName: j['displayName'] as String,
          ),
        )
        .toList(),
    mushafs: (json['mushafs'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafFromJson)
        .toList(),
    mushafLines: (json['mushafLines'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafLineFromJson)
        .toList(),
    mushafTokens: json['mushafTokens'] == null
        ? const []
        : (json['mushafTokens'] as List)
              .cast<Map<String, dynamic>>()
              .map(mushafTokenFromJson)
              .toList(),
    navigationRanges: (json['navigationRanges'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => NavigationRange(
            type: NavigationUnitType.values.byName(j['type'] as String),
            unitNo: j['unitNo'] as int,
            surahNo: j['surahNo'] as int,
            startAyahNo: j['startAyahNo'] as int,
            endAyahNo: j['endAyahNo'] as int,
          ),
        )
        .toList(),
    metadata: DatasetMetadata(
      datasetVersion:
          (json['metadata'] as Map<String, dynamic>)['datasetVersion']
              as String,
      contentHash:
          (json['metadata'] as Map<String, dynamic>)['contentHash'] as String,
      importedAt: DateTime.parse(
        (json['metadata'] as Map<String, dynamic>)['importedAt'] as String,
      ),
    ),
  );
}

Map<String, dynamic> translationBookToJson(TranslationBook b) => {
  'slug': b.slug,
  'displayName': b.displayName,
  'languageCode': b.languageCode,
  'author': b.author,
  'version': b.version,
  'source': b.source,
  'license': b.license,
  'checksum': b.checksum,
  'formatVersion': b.formatVersion,
};

TranslationBook translationBookFromJson(Map<String, dynamic> j) =>
    TranslationBook(
      slug: j['slug'] as String,
      displayName: j['displayName'] as String,
      languageCode: j['languageCode'] as String,
      author: j['author'] as String,
      version: j['version'] as int,
      source: j['source'] as String,
      license: j['license'] as String,
      checksum: j['checksum'] as String,
      formatVersion: j['formatVersion'] as int,
    );

Map<String, dynamic> translationVerseToJson(TranslationVerseText v) => {
  'slug': v.slug,
  'chapterNo': v.chapterNo,
  'verseNo': v.verseNo,
  'text': v.text,
  if (v.footnotes.isNotEmpty)
    'footnotes': v.footnotes
        .map((f) => {'marker': f.marker, 'text': f.text})
        .toList(),
};

TranslationVerseText translationVerseFromJson(Map<String, dynamic> j) =>
    TranslationVerseText(
      slug: j['slug'] as String,
      chapterNo: j['chapterNo'] as int,
      verseNo: j['verseNo'] as int,
      text: j['text'] as String,
      footnotes: j['footnotes'] == null
          ? const []
          : (j['footnotes'] as List)
                .cast<Map<String, dynamic>>()
                .map(
                  (f) => TranslationFootnote(
                    marker: f['marker'] as int,
                    text: f['text'] as String,
                  ),
                )
                .toList(),
    );

Map<String, dynamic> tafsirWorkToJson(TafsirWork w) => {
  'id': w.id,
  'displayName': w.displayName,
  'languageCode': w.languageCode,
  'author': w.author,
  'version': w.version,
  'source': w.source,
  'license': w.license,
  'checksum': w.checksum,
  'formatVersion': w.formatVersion,
};

TafsirWork tafsirWorkFromJson(Map<String, dynamic> j) => TafsirWork(
  id: j['id'] as String,
  displayName: j['displayName'] as String,
  languageCode: j['languageCode'] as String,
  author: j['author'] as String,
  version: j['version'] as int,
  source: j['source'] as String,
  license: j['license'] as String,
  checksum: j['checksum'] as String,
  formatVersion: j['formatVersion'] as int,
);

Map<String, dynamic> tafsirVerseToJson(TafsirVerseText v) => {
  'tafsirId': v.tafsirId,
  'chapterNo': v.chapterNo,
  'verseNo': v.verseNo,
  'text': v.text,
};

TafsirVerseText tafsirVerseFromJson(Map<String, dynamic> j) => TafsirVerseText(
  tafsirId: j['tafsirId'] as String,
  chapterNo: j['chapterNo'] as int,
  verseNo: j['verseNo'] as int,
  text: j['text'] as String,
);
