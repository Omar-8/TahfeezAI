import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/data/quranapp_special_font_manifest_codec.dart';
import '../../../quran/domain/models/quranapp_special_font_models.dart';

part 'quranapp_special_font_providers.g.dart';

const _quranCommonManifestAsset =
    'assets/quran/manifests/quran_common_font.json';
const _suraconManifestAsset = 'assets/quran/manifests/suracon_glyphs.json';
const _uthmanicHafsManifestAsset =
    'assets/quran/manifests/uthmanic_hafs_font.json';

/// The verified `quran_common.ttf` manifest, with its font already
/// registered via `FontLoader` — or `null` if it isn't bundled in this
/// build, or this is a release build (QuranApp's redistribution terms for
/// this font remain unverified, `SHIP_BLOCKED_LICENSE` — see
/// `docs/QURAN_DATA_PROVENANCE.md` §12/§13). A `null` result is an
/// expected, honest state: callers fall back to plain-text Bismillah,
/// never a fabricated substitute glyph.
@Riverpod(keepAlive: true)
Future<QuranCommonFontManifest?> quranCommonFontManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_quranCommonManifestAsset);
  } catch (_) {
    return null;
  }
  final manifest = quranCommonFontManifestFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );

  final fontData = await rootBundle.load(manifest.assetPath);
  await (FontLoader(
    manifest.fontFamily,
  )..addFont(Future.value(fontData))).load();

  return manifest;
}

/// The verified `uthmanic_hafs.ttf` ("KFGQPC HAFS Uthmanic Script") manifest
/// — also distributed as QUL's own `UthmanicHafs_V22.ttf` (confirmed
/// byte-identical). Used by the verse-by-verse reader's Arabic text
/// (`lib/features/reader/application/quran_display_providers.dart`),
/// paired *only* with that same font's own QPC Hafs display-word script —
/// never with plain canonical `AyahWord` text, which real-font rendering
/// confirmed this font does not shape correctly (`docs/
/// QURAN_DATA_PROVENANCE.md` §16's "Rendering history"). Same
/// `SHIP_BLOCKED_LICENSE`/`kReleaseMode` gate as the other fonts in this
/// file. `null` means callers fall back to the platform's own default
/// Arabic-capable system font.
@Riverpod(keepAlive: true)
Future<QuranCommonFontManifest?> uthmanicHafsFontManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_uthmanicHafsManifestAsset);
  } catch (_) {
    return null;
  }
  final manifest = quranCommonFontManifestFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );

  final fontData = await rootBundle.load(manifest.assetPath);
  await (FontLoader(
    manifest.fontFamily,
  )..addFont(Future.value(fontData))).load();

  return manifest;
}

/// The verified `suracon.ttf` glyph manifest, with its font already
/// registered — same `SHIP_BLOCKED_LICENSE`/`kReleaseMode` gate as
/// [quranCommonFontManifestProvider]. `null` means callers fall back to
/// plain localized Surah-name text, never a fabricated substitute glyph.
@Riverpod(keepAlive: true)
Future<SuraconGlyphManifest?> suraconGlyphManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_suraconManifestAsset);
  } catch (_) {
    return null;
  }
  final manifest = suraconGlyphManifestFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );

  final fontData = await rootBundle.load(manifest.assetPath);
  await (FontLoader(
    manifest.fontFamily,
  )..addFont(Future.value(fontData))).load();

  return manifest;
}
