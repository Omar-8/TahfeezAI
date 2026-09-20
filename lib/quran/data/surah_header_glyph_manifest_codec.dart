import '../domain/models/surah_header_glyph_models.dart';

/// Decodes a [SurahHeaderGlyphManifest] written by
/// `tool/quran_data/src/surah_header_font_package.dart`
/// (`assets/quran/manifests/surah_header_glyphs.json`). The inverse encoder
/// lives in the tool script, since only the build tool ever writes this
/// file — the running app only ever reads it.
SurahHeaderGlyphManifest surahHeaderGlyphManifestFromJson(
  Map<String, dynamic> json,
) {
  return SurahHeaderGlyphManifest(
    schemaVersion: json['schemaVersion'] as int,
    assetPath: json['assetPath'] as String,
    fontFamily: json['fontFamily'] as String,
    fontSource: json['fontSource'] as String,
    fontHash: json['fontHash'] as String,
    ligatureMappingSource: json['ligatureMappingSource'] as String,
    ligatureMappingHash: json['ligatureMappingHash'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    entries: (json['entries'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => SurahHeaderGlyphEntry(
            surahNumber: j['surahNumber'] as int,
            inputText: j['inputText'] as String,
            fontFamily: j['fontFamily'] as String,
          ),
        )
        .toList(),
  );
}
