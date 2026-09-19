import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/logging_package_logger.dart';
import '../../../quran/data/page_font_manifest_codec.dart';
import '../../../quran/domain/models/page_font_manifest_models.dart';
import '../data/font_loader_qpc_page_font_manager.dart';
import '../domain/qpc_page_font_manager.dart';

part 'qpc_page_font_providers.g.dart';

const _manifestAsset = 'assets/quran/manifests/qpc_v2_fonts.json';

/// The generated QPC V2 page->font manifest, or `null` if it is not bundled
/// in this build, or if this is a release build — see
/// `docs/QURAN_DATA_PROVENANCE.md` §8. QUL's redistribution terms remain
/// unverified (`SHIP_BLOCKED_LICENSE`), so this refuses to load the
/// manifest in `kReleaseMode` even if the asset bytes happen to be present
/// in a naively-built release package — the app's own code must never
/// display this content in a real release build. A `null` result is an
/// expected, honest state, never treated as an error.
@Riverpod(keepAlive: true)
Future<PageFontManifest?> qpcPageFontManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_manifestAsset);
  } catch (_) {
    return null;
  }
  return pageFontManifestFromJson(jsonDecode(raw) as Map<String, dynamic>);
}

@Riverpod(keepAlive: true)
AppLogger qpcPageFontLogger(Ref ref) => LoggingPackageLogger();

/// The app-wide [QpcPageFontManager], or `null` when no font manifest is
/// bundled (see [qpcPageFontManifestProvider]) — presentation code must
/// treat a `null` manager as "Mushaf glyph rendering unavailable," never
/// substitute a fallback font.
@Riverpod(keepAlive: true)
Future<QpcPageFontManager?> qpcPageFontManager(Ref ref) async {
  final manifest = await ref.watch(qpcPageFontManifestProvider.future);
  if (manifest == null) return null;
  return FontLoaderQpcPageFontManager(
    manifest: manifest,
    logger: ref.watch(qpcPageFontLoggerProvider),
  );
}

/// Ensures [pageNumber]'s font is loaded, returning the handle to render
/// with — or `null` if no font manager is bundled at all (the honest
/// `SHIP_BLOCKED_LICENSE` state, per `docs/QURAN_DATA_PROVENANCE.md` §8),
/// in which case the caller shows a "font packaging pending" state rather
/// than falling back to any other font.
///
/// This is deliberately its own provider (rather than an imperative
/// `ensureLoaded` call inside a widget's build method): Riverpod's own
/// provider-family semantics already give rapid page swiping the exact
/// race-safety this needs for free — a widget only ever watches the
/// *current* page's provider, so a slow-to-resolve previous page's future
/// resolving late cannot overwrite what a later page's build already
/// rendered, since nothing still watches it.
@riverpod
Future<PageFontHandle?> mushafPageFont(
  Ref ref,
  int mushafId,
  int pageNumber,
) async {
  final manager = await ref.watch(qpcPageFontManagerProvider.future);
  if (manager == null) return null;
  // Fire-and-forget: neighbors load opportunistically and must never delay
  // the current page's own font (awaited below).
  unawaited(manager.preloadAround(mushafId, pageNumber));
  return manager.ensureLoaded(mushafId, pageNumber);
}
