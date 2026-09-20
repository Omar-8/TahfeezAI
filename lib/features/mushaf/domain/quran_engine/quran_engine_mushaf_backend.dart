import 'package:flutter/widgets.dart'
    show Widget, ValueChanged, VoidCallback, Color;

import '../../../../quran/domain/models/quran_refs.dart';
import '../../presentation/mushaf_page_render_model.dart'
    show MushafTokenHitRect;

/// Thrown by a [QuranEngineMushafBackend] when asked to load a page in a
/// release build — Quran Engine's own page corpus is KFGQPC-derived with
/// the same unresolved redistribution status as Tahfeez's existing QPC V2
/// fonts (`docs/QURAN_ENGINE_MIGRATION.md`'s licensing section), so it is
/// gated exactly like every other license-blocked Mushaf resource in this
/// codebase (`docs/QURAN_DATA_PROVENANCE.md`'s release checklist): never
/// loaded when `kReleaseMode` is true, regardless of whether the asset
/// bytes happen to be physically present. Presentation code distinguishes
/// this from a genuine load failure the same way
/// `QpcWebFontDeliveryNotConfiguredException` is distinguished from a real
/// font-fetch error.
class QuranEngineReleaseModeBlockedException implements Exception {
  const QuranEngineReleaseModeBlockedException(this.pageNumber);

  final int pageNumber;

  @override
  String toString() =>
      'QuranEngineReleaseModeBlockedException(page $pageNumber): the Quran '
      'Engine page corpus is not loaded in release builds — see '
      'docs/QURAN_ENGINE_MIGRATION.md.';
}

/// Thrown by the Web backend when the Quran Engine page-delivery endpoint
/// is not configured (`QURAN_ENGINE_PAGE_BASE_URL` unset) — the honest,
/// expected `SHIP_BLOCKED_LICENSE` state, never a silent fallback.
/// Distinguished from a genuine fetch failure the same way
/// `QpcWebFontDeliveryNotConfiguredException` is. Lives here (not in the
/// Web-only backend file) so platform-agnostic presentation code — which
/// must compile on Android too — can catch it without importing anything
/// `dart:js_interop`-dependent.
class QuranEngineWebDeliveryNotConfiguredException implements Exception {
  const QuranEngineWebDeliveryNotConfiguredException(this.pageNumber);

  final int pageNumber;

  @override
  String toString() =>
      'QuranEngineWebDeliveryNotConfiguredException(page $pageNumber): '
      'QURAN_ENGINE_PAGE_BASE_URL is not set — see '
      'docs/QURAN_ENGINE_MIGRATION.md.';
}

/// A thin, platform-independent facade over Quran.ws's "Quran Engine"
/// (`https://github.com/quran-ws/quran-engine`), promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`docs/poc/QURAN_ENGINE_POC.md`) into a real Mushaf rendering backend —
/// see `docs/QURAN_ENGINE_MIGRATION.md`.
///
/// Two implementations exist, chosen by [MushafRenderBackendController]'s
/// selection reaching `mushafQuranEngineBackendProvider`'s single platform
/// branch: `QuranEngineAndroidBackend` (Android, via the official
/// `qvp_flutter` wrapper) and a Web implementation (via the official
/// `qvp.js`/WASM wrapper, promoted from the POC's own bridge — pending,
/// see the migration doc's status).
///
/// Every hit this backend reports comes back as Tahfeez's own
/// [MushafTokenHitRect] — the exact type the existing QPC V2 renderer
/// already reports through `MushafPager`/`MushafPageView` — so neither of
/// those files needs to know which backend actually drew the page. Word/
/// ayah *targets* (for highlight/mask) are expressed with Tahfeez's own
/// canonical [WordRef]/[VerseRef]
/// (`lib/quran/domain/models/quran_refs.dart`), translated to/from Quran
/// Engine's own key format exclusively by [QuranEngineRefAdapter]
/// (`../quran_engine_ref_adapter.dart`) — never parsed ad hoc here or in
/// any concrete implementation.
abstract class QuranEngineMushafBackend {
  /// Human-readable identification of the concrete Quran Engine build this
  /// backend wraps — for diagnostics only, never used for logic.
  Future<String> initialize();

  /// Loads [pageNumber]'s Quran Engine page data. Throws if the page's data
  /// isn't available for the current platform/configuration — never falls
  /// back to a different page's data or to the QPC V2 renderer (that
  /// fallback decision belongs to whatever calls this, e.g.
  /// `MushafPageView`, not to the backend itself).
  Future<QuranEngineMushafPage> loadPage(int pageNumber);

  void disposePage(QuranEngineMushafPage page);

  /// Fire-and-forget warmup of [pageNumber]'s neighbors, mirroring
  /// `QpcPageFontManager.preloadAround`'s exact role for the QPC V2
  /// renderer. Meaningful only for a backend with a real transport cost
  /// per page (Web, fetching over HTTP); a backend serving from bundled
  /// local assets (Android) may no-op this. Never awaited by a caller, and
  /// a failing/slow neighbor must never affect the page actually on
  /// screen.
  Future<void> preloadAround(int pageNumber, {int radius = 1});
}

/// One loaded Quran Engine page. [buildView] returns the actual platform
/// widget that draws it — the engine's own official widget/canvas, never a
/// Tahfeez-reimplemented renderer, per the migration's "QVP content owns
/// the printed page" requirement.
abstract class QuranEngineMushafPage {
  int get pageNumber;

  /// The page's own natural aspect ratio (width / height) — callers size
  /// this page's container to preserve it (uniform scale, never
  /// independent X/Y stretch).
  double get aspectRatio;

  /// Builds the rendering + gesture-handling widget for this page, themed
  /// from [ink]/[paper] (mapped directly from `MushafAppearanceColors.text`/
  /// `.background` at the one call site,
  /// `QuranEngineMushafPageContent.build` in
  /// `../../presentation/quran_engine_mushaf_page_content.dart`).
  /// [onWordHit]/[onDecorationHit] fire with the same [MushafTokenHitRect]
  /// shape the existing QPC V2 renderer already reports through
  /// `MushafPager`/`MushafPageView`.
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
  });

  /// Highlights [target] (a [WordRef] or [VerseRef]) — 'band' is the only
  /// mode this migration currently exercises (selected/current-word style
  /// highlighting for future audio/memorization use, per the migration's
  /// "moving highlight" requirement).
  int highlightWord(WordRef target, {String mode = 'band'});
  int highlightAyah(VerseRef target, {String mode = 'band'});

  void clearHighlights();

  /// Masks (hides) [target] for memorization practice.
  void maskWord(WordRef target, {String mode = 'hide'});
  void maskAyah(VerseRef target, {String mode = 'hide'});

  /// Reveals the next [count] currently-masked word(s), in reading order.
  void revealNext([int count = 1]);

  void unmask();

  void dispose();
}
