import '../domain/models/page_font_manifest_models.dart';

/// Decodes a [PageFontManifest] written by
/// `tool/quran_data/src/qpc_font_package.dart`
/// (`assets/quran/manifests/qpc_v2_fonts.json`). The inverse encoder
/// (`pageFontManifestToJson`) lives in the tool script, since only the
/// build tool ever writes this file — the running app only ever reads it.
PageFontManifest pageFontManifestFromJson(Map<String, dynamic> json) {
  return PageFontManifest(
    schemaVersion: json['schemaVersion'] as int,
    mushafId: json['mushafId'] as int,
    fontPackageSource: json['fontPackageSource'] as String,
    fontPackageHash: json['fontPackageHash'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    entries: (json['entries'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (j) => PageFontManifestEntry(
            mushafId: j['mushafId'] as int,
            pageNumber: j['pageNumber'] as int,
            assetPath: j['assetPath'] as String,
            fontFamily: j['fontFamily'] as String,
            sourceFile: j['sourceFile'] as String,
            fileHash: j['fileHash'] as String,
            fileSize: j['fileSize'] as int,
          ),
        )
        .toList(),
  );
}
