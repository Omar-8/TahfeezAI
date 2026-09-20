import '../domain/models/quranapp_special_font_models.dart';

/// Decodes manifests written by
/// `tool/quran_data/src/quranapp_font_package.dart`. The inverse encoders
/// live in the tool script, since only the build tool ever writes these
/// files — the running app only ever reads them.
QuranCommonFontManifest quranCommonFontManifestFromJson(
  Map<String, dynamic> json,
) {
  return QuranCommonFontManifest(
    schemaVersion: json['schemaVersion'] as int,
    assetPath: json['assetPath'] as String,
    fontFamily: json['fontFamily'] as String,
    fontSource: json['fontSource'] as String,
    fontHash: json['fontHash'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
  );
}

SuraconGlyphManifest suraconGlyphManifestFromJson(Map<String, dynamic> json) {
  return SuraconGlyphManifest(
    schemaVersion: json['schemaVersion'] as int,
    assetPath: json['assetPath'] as String,
    fontFamily: json['fontFamily'] as String,
    fontSource: json['fontSource'] as String,
    fontHash: json['fontHash'] as String,
    prefixInputText: json['prefixInputText'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    entries: (json['entries'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => SuraconGlyphEntry(
            surahNumber: j['surahNumber'] as int,
            inputText: j['inputText'] as String,
          ),
        )
        .toList(),
  );
}
