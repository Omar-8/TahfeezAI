import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/network_client.dart';
import '../../../quran/domain/models/page_font_manifest_models.dart';
import '../domain/qpc_page_font_manager.dart';

/// [QpcPageFontManager] for Web: fetches exactly the requested page's font
/// bytes over HTTP from [baseUrl] instead of `rootBundle` — the 604 QPC V2
/// font files are never bundled into a Web build at all (they are excluded
/// at build time, see `tool/build_web.dart`), so there is nothing local to
/// load them from.
///
/// [baseUrl] is `null`/empty by default (`QPC_FONT_BASE_URL` unset) —
/// QPC V2 redistribution over any public endpoint remains
/// `SHIP_BLOCKED_LICENSE` (`docs/QURAN_DATA_PROVENANCE.md` §8) until
/// upstream permission is confirmed, so there is deliberately no default,
/// fallback, or hard-coded URL here. Every [ensureLoaded] call fails with
/// [QpcWebFontDeliveryNotConfiguredException] until a real, legally cleared
/// endpoint is supplied at build time via `--dart-define=QPC_FONT_BASE_URL=…`
/// — never a silent fallback to a system font, and never QPC glyph text
/// painted with the wrong font.
///
/// The resource path is entirely manifest-driven — `{baseUrl}/qpc-v2/
/// {fontPackageHash}/{sourceFile}` — using [PageFontManifest.fontPackageHash]
/// (a real hash of the whole vendored font package) as a content-addressable
/// version segment and each entry's own [PageFontManifestEntry.sourceFile]
/// name, never a recomputed/padded page-number string built independently
/// of the manifest. A future deployment can serve these under a long,
/// immutable `Cache-Control` (the hash-versioned path already makes that
/// safe — a font-package update naturally changes the URL) and rely on
/// ordinary browser HTTP caching; this class has no cache of its own beyond
/// the in-memory [_loaded]/[_inFlight] bookkeeping every implementation of
/// this interface needs regardless of transport.
class WebQpcPageFontManager implements QpcPageFontManager {
  WebQpcPageFontManager({
    required PageFontManifest manifest,
    required this.logger,
    required this.networkClient,
    required this.baseUrl,
  }) : _fontPackageHash = manifest.fontPackageHash,
       _entriesByPage = {
         for (final e in manifest.entries) (e.mushafId, e.pageNumber): e,
       };

  final AppLogger logger;
  final NetworkClient networkClient;

  /// `QPC_FONT_BASE_URL`'s resolved value — `null`/empty means "not
  /// configured", never a hard-coded default.
  final String? baseUrl;

  final String _fontPackageHash;
  final Map<(int, int), PageFontManifestEntry> _entriesByPage;

  final Set<(int, int)> _loaded = {};
  final Map<(int, int), Future<PageFontHandle>> _inFlight = {};

  bool get _isConfigured => baseUrl != null && baseUrl!.trim().isNotEmpty;

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
      logger.error(exception.toString(), tag: 'WebQpcPageFontManager');
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

    if (!_isConfigured) {
      final exception = QpcWebFontDeliveryNotConfiguredException(
        mushafId: mushafId,
        pageNumber: pageNumber,
      );
      // `debug`, not `error`: an unconfigured endpoint is the honest,
      // expected state while redistribution remains SHIP_BLOCKED_LICENSE —
      // not a bug to investigate, unlike a real fetch failure below.
      logger.debug(exception.toString(), tag: 'WebQpcPageFontManager');
      return Future.error(exception);
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
      final response = await networkClient.getBytes(_resourceUrl(entry));
      final data = response.data;
      if (data == null) {
        throw StateError('Empty response body for ${_resourceUrl(entry)}');
      }
      final bytes = Uint8List.fromList(data);
      final loader = FontLoader(entry.fontFamily)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
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
        assetPath: _resourceUrl(entry),
        reason: e,
      );
      logger.error(
        exception.toString(),
        tag: 'WebQpcPageFontManager',
        error: e,
        stackTrace: st,
      );
      throw exception;
    } finally {
      // Removing the in-flight entry on failure (not just on success) is
      // what allows a later retry — e.g. the user swiping back to this
      // page again after a transient network error — rather than the
      // page's font being permanently stuck failed for the rest of the
      // session.
      _inFlight.remove(key);
    }
  }

  String _resourceUrl(PageFontManifestEntry entry) {
    final base = baseUrl!.endsWith('/')
        ? baseUrl!.substring(0, baseUrl!.length - 1)
        : baseUrl!;
    return '$base/qpc-v2/$_fontPackageHash/${entry.sourceFile}';
  }

  @override
  Future<void> preloadAround(
    int mushafId,
    int pageNumber, {
    int radius = 2,
  }) async {
    if (!_isConfigured) return;
    for (var distance = 1; distance <= radius; distance++) {
      for (final neighbor in [pageNumber - distance, pageNumber + distance]) {
        if (!_entriesByPage.containsKey((mushafId, neighbor))) continue;
        // Fire-and-forget: a neighbor failing or being slow to preload must
        // never affect the page currently on screen.
        unawaited(
          ensureLoaded(mushafId, neighbor).catchError((Object e) {
            logger.warning(
              'Preload failed for Mushaf $mushafId page $neighbor: $e',
              tag: 'WebQpcPageFontManager',
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
