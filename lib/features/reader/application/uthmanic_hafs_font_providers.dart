import 'dart:convert';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/data/quranapp_special_font_manifest_codec.dart';
import '../../../quran/domain/models/quranapp_special_font_models.dart';

part 'uthmanic_hafs_font_providers.g.dart';

const _uthmanicHafsManifestAsset =
    'assets/quran/manifests/uthmanic_hafs_font.json';

/// The verified `uthmanic_hafs.ttf` ("KFGQPC HAFS Uthmanic Script") manifest
/// — also distributed as QUL's own `UthmanicHafs_V22.ttf` (confirmed
/// byte-identical). Used by the verse-by-verse reader's Arabic text
/// (`verse_block.dart`), paired *only* with that same font's own QPC Hafs
/// display-word script — never with plain canonical `AyahWord` text, which
/// real-font rendering confirmed this font does not shape correctly
/// (`docs/QURAN_DATA_PROVENANCE.md` §16's "Rendering history").
///
/// Moved here from `lib/features/mushaf/application/
/// quranapp_special_font_providers.dart` when the Mushaf-mode-only
/// `quran_common.ttf`/`suracon.ttf` providers in that file were removed
/// as part of the Quran Engine migration — this font belongs to
/// verse-by-verse mode, not the Mushaf renderer, and verse-by-verse mode
/// is explicitly out of scope for that migration
/// (`docs/QURAN_ENGINE_MIGRATION.md`).
///
/// `null` means callers fall back to the platform's own default
/// Arabic-capable system font — an expected, honest state, never a
/// fabricated substitute glyph.
@Riverpod(keepAlive: true)
Future<QuranCommonFontManifest?> uthmanicHafsFontManifest(Ref ref) async {
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
