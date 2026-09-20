/// One page's font, confirmed loaded and ready to use as a `TextStyle`'s
/// `fontFamily`.
class PageFontHandle {
  const PageFontHandle({
    required this.mushafId,
    required this.pageNumber,
    required this.fontFamily,
  });

  final int mushafId;
  final int pageNumber;
  final String fontFamily;
}

/// Thrown when a page's font could not be loaded — surfaced with enough
/// detail to log (Mushaf id, page number, expected asset, reason), never
/// silently swallowed into a fallback font.
class QpcPageFontLoadException implements Exception {
  QpcPageFontLoadException({
    required this.mushafId,
    required this.pageNumber,
    required this.assetPath,
    required this.reason,
  });

  final int mushafId;
  final int pageNumber;
  final String assetPath;
  final Object reason;

  @override
  String toString() =>
      'Failed to load QPC page font for Mushaf $mushafId page $pageNumber '
      '(asset $assetPath): $reason';
}

/// Thrown by the Web implementation when no font-delivery endpoint is
/// configured (`QPC_FONT_BASE_URL` unset at build time) — QPC V2
/// redistribution remains `SHIP_BLOCKED_LICENSE`
/// (`docs/QURAN_DATA_PROVENANCE.md` §8), so a production Web build has no
/// endpoint to fetch from until that clears, and this is the honest,
/// distinguishable-from-a-network-failure signal for that state. Never
/// caught and silently turned into a fallback font — presentation code
/// checks for this specific type to show "Mushaf page font resources are
/// not configured for Web." instead of a generic load-failure message.
class QpcWebFontDeliveryNotConfiguredException implements Exception {
  QpcWebFontDeliveryNotConfiguredException({
    required this.mushafId,
    required this.pageNumber,
  });

  final int mushafId;
  final int pageNumber;

  @override
  String toString() =>
      'QPC Web font delivery is not configured (QPC_FONT_BASE_URL unset) — '
      'Mushaf $mushafId page $pageNumber font unavailable on Web.';
}

/// Lazily loads and registers QCF V2's page-specific fonts, one at a time,
/// as Mushaf pages are actually viewed — never eagerly registering all 604
/// font families at startup (per `docs/QURAN_DATA_PROVENANCE.md` §8's
/// font-packaging decision).
///
/// Every method here must be concurrency-safe: concurrent requests for the
/// same page must share one underlying load, never trigger duplicate
/// registration. There is deliberately no "unload"/"evict" method — Flutter
/// does not provide a supported production API for unregistering a font
/// family a `FontLoader` has already registered, so once a page's font is
/// loaded it stays loaded for the life of the app process; only *which*
/// pages get loaded in the first place is controlled (current page ±2 by
/// default), not their lifetime.
///
/// Two implementations, chosen by platform
/// (`lib/features/mushaf/application/qpc_page_font_providers.dart`), never
/// forking anything else in the Mushaf stack:
/// - `FontLoaderQpcPageFontManager`
///   (`lib/features/mushaf/data/font_loader_qpc_page_font_manager.dart`) —
///   native (Android/iOS): `rootBundle` against the real, bundled,
///   page-specific QPC V2 font files. Fully offline, unchanged by the Web
///   font-delivery work.
/// - `WebQpcPageFontManager`
///   (`lib/features/mushaf/data/web_qpc_page_font_manager.dart`) — Web:
///   fetches the one requested page's font bytes over HTTP from a
///   configurable, currently-unset-by-default endpoint (see
///   [QpcWebFontDeliveryNotConfiguredException]).
///
/// Either way, presentation code only ever sees this interface — it never
/// knows the asset-path/font-family naming convention, or which concrete
/// implementation is in use.
abstract class QpcPageFontManager {
  /// Ensures [pageNumber]'s font is loaded and registered, returning a
  /// handle once it is. Must be awaited by the renderer *before* that
  /// page's Quran glyph text becomes visible — never render with a
  /// fallback/previous-page font while this is pending.
  Future<PageFontHandle> ensureLoaded(int mushafId, int pageNumber);

  /// Best-effort, fire-and-forget loading of the pages around [pageNumber]
  /// (default radius 2, i.e. up to 4 neighbors) — never awaited by a
  /// renderer and never blocks the current page's own [ensureLoaded] call.
  /// Errors loading a neighbor are logged, not thrown, since a neighbor's
  /// font failing to preload must not affect the page currently on screen.
  Future<void> preloadAround(int mushafId, int pageNumber, {int radius = 2});

  /// Whether [pageNumber]'s font has already been loaded and registered —
  /// synchronous, since it never needs to touch the asset bundle.
  bool isLoaded(int mushafId, int pageNumber);

  /// The font family [pageNumber] resolves to, from the manifest, whether
  /// or not it has been loaded yet — callers must still confirm
  /// [isLoaded] (or await [ensureLoaded]) before using this in a
  /// `TextStyle`; a family name alone does not mean the bytes are
  /// registered.
  String? fontFamilyFor(int mushafId, int pageNumber);
}
