import 'dart:async' show unawaited;

import 'package:flutter/services.dart' show FontLoader, rootBundle;

import '../../../core/logging/app_logger.dart';
import '../../../quran/domain/models/page_font_manifest_models.dart';
import '../domain/qpc_page_font_manager.dart';

/// [QpcPageFontManager] backed by `dart:ui`'s [ui.FontLoader] and the real,
/// bundled, page-specific QPC V2 font assets described by a
/// [PageFontManifest] — see that manifest's own doc comment for how it was
/// generated and verified.
class FontLoaderQpcPageFontManager implements QpcPageFontManager {
  FontLoaderQpcPageFontManager({
    required PageFontManifest manifest,
    required this.logger,
  }) : _entriesByPage = {
         for (final e in manifest.entries) (e.mushafId, e.pageNumber): e,
       };

  final AppLogger logger;
  final Map<(int, int), PageFontManifestEntry> _entriesByPage;

  final Set<(int, int)> _loaded = {};
  final Map<(int, int), Future<PageFontHandle>> _inFlight = {};

  @override
  bool isLoaded(int mushafId, int pageNumber) =>
      _loaded.contains((mushafId, pageNumber));

  @override
  String? fontFamilyFor(int mushafId, int pageNumber) =>
      _entriesByPage[(mushafId, pageNumber)]?.fontFamily;

  @override
  Future<PageFontHandle> ensureLoaded(int mushafId, int pageNumber) {
    final key = (mushafId, pageNumber);
    final entry = _entriesByPage[key];
    if (entry == null) {
      final exception = QpcPageFontLoadException(
        mushafId: mushafId,
        pageNumber: pageNumber,
        assetPath: '(no manifest entry)',
        reason: 'No page-font manifest entry for this Mushaf/page.',
      );
      logger.error(exception.toString(), tag: 'QpcPageFontManager');
      return Future.error(exception);
    }

    if (_loaded.contains(key)) {
      return Future.value(
        PageFontHandle(
          mushafId: mushafId,
          pageNumber: pageNumber,
          fontFamily: entry.fontFamily,
        ),
      );
    }

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _load(entry);
    _inFlight[key] = future;
    return future;
  }

  Future<PageFontHandle> _load(PageFontManifestEntry entry) async {
    final key = (entry.mushafId, entry.pageNumber);
    try {
      final loader = FontLoader(entry.fontFamily);
      loader.addFont(rootBundle.load(entry.assetPath));
      await loader.load();

      _loaded.add(key);
      return PageFontHandle(
        mushafId: entry.mushafId,
        pageNumber: entry.pageNumber,
        fontFamily: entry.fontFamily,
      );
    } catch (e, st) {
      final exception = QpcPageFontLoadException(
        mushafId: entry.mushafId,
        pageNumber: entry.pageNumber,
        assetPath: entry.assetPath,
        reason: e,
      );
      logger.error(
        exception.toString(),
        tag: 'QpcPageFontManager',
        error: e,
        stackTrace: st,
      );
      throw exception;
    } finally {
      _inFlight.remove(key);
    }
  }

  @override
  Future<void> preloadAround(
    int mushafId,
    int pageNumber, {
    int radius = 2,
  }) async {
    for (var distance = 1; distance <= radius; distance++) {
      for (final neighbor in [pageNumber - distance, pageNumber + distance]) {
        if (!_entriesByPage.containsKey((mushafId, neighbor))) continue;
        // Fire-and-forget: a neighbor failing or being slow to preload must
        // never affect the page currently on screen.
        unawaited(
          ensureLoaded(mushafId, neighbor).catchError((Object e) {
            logger.warning(
              'Preload failed for Mushaf $mushafId page $neighbor: $e',
              tag: 'QpcPageFontManager',
            );
            return PageFontHandle(
              mushafId: mushafId,
              pageNumber: neighbor,
              fontFamily: '',
            );
          }),
        );
      }
    }
  }
}
