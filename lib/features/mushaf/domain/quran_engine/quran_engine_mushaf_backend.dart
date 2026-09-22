import 'package:flutter/widgets.dart'
    show Widget, ValueChanged, VoidCallback, Color;

import '../../../../quran/domain/models/quran_refs.dart';
import '../../presentation/mushaf_token_hit_rect.dart' show MushafTokenHitRect;

/// A thin, platform-independent facade over Quran.ws's "Quran Engine"
/// (`https://github.com/quran-ws/quran-engine`), promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`docs/poc/QURAN_ENGINE_POC.md`) into Tahfeez's production Mushaf
/// renderer — see `docs/QURAN_ENGINE_MIGRATION.md`. Quran Engine is now
/// the **only** Mushaf rendering backend (the former QPC V2 renderer was
/// removed once this migration completed).
///
/// Two implementations exist, chosen by `mushafQuranEngineBackendProvider`'s
/// single platform branch: `QuranEngineAndroidBackend` (Android, via the
/// official `qvp_flutter` wrapper) and `QuranEngineWebBackend` (Web, via
/// the official `qvp.js`/WASM wrapper).
///
/// Every hit this backend reports comes back as Tahfeez's own
/// [MushafTokenHitRect] — the same type `MushafPager`/`MushafPageView`
/// consume regardless of platform, so neither of those files needs to
/// know which platform's adapter actually drew the page. Word/ayah
/// *targets* (for highlight/mask) are expressed with Tahfeez's own
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
  /// isn't available for the current platform/configuration.
  Future<QuranEngineMushafPage> loadPage(int pageNumber);

  void disposePage(QuranEngineMushafPage page);

  /// Fire-and-forget warmup of [pageNumber]'s neighbors. Meaningful only
  /// for a backend with a real transport cost per page (Web, fetching
  /// over HTTP); a backend serving from bundled local assets (Android)
  /// may no-op this. Never awaited by a caller, and a failing/slow
  /// neighbor must never affect the page actually on screen.
  Future<void> preloadAround(int pageNumber, {int radius = 1});
}

/// One loaded Quran Engine page. [buildView] returns the actual platform
/// widget that draws it — the engine's own official widget/canvas, never a
/// Tahfeez-reimplemented renderer.
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
  /// [onWordHit]/[onDecorationHit] fire with [MushafTokenHitRect].
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
  });

  /// Highlights [target] (a [WordRef] or [VerseRef]) — 'band' is the only
  /// mode this migration currently exercises (selected/current-word style
  /// highlighting for future audio/memorization use).
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
