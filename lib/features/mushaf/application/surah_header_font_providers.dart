import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/data/surah_header_glyph_manifest_codec.dart';
import '../../../quran/domain/models/surah_header_glyph_models.dart';

part 'surah_header_font_providers.g.dart';

const _manifestAsset = 'assets/quran/manifests/surah_header_glyphs.json';

/// The generated Surah Header glyph manifest, with its font already
/// registered via `FontLoader` — or `null` if it is not bundled in this
/// build, or this is a release build (see
/// `docs/QURAN_DATA_PROVENANCE.md`: QUL's redistribution terms for this
/// font remain unverified, `SHIP_BLOCKED_LICENSE`). A single shared font
/// used across every Surah-header line on every page — unlike the
/// per-page QPC V2 fonts, there is exactly one file to load once, so this
/// collapses manifest-loading and font-registration into one provider
/// rather than a separate manager class. A `null` result is an expected,
/// honest state: callers fall back to plain localized text, never a
/// fabricated decorative substitute.
@Riverpod(keepAlive: true)
Future<SurahHeaderGlyphManifest?> surahHeaderGlyphManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_manifestAsset);
  } catch (_) {
    return null;
  }
  final manifest = surahHeaderGlyphManifestFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );

  final fontData = await rootBundle.load(manifest.assetPath);
  await (FontLoader(
    manifest.fontFamily,
  )..addFont(Future.value(fontData))).load();

  return manifest;
}
