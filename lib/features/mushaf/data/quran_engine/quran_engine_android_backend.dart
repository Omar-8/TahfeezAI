import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:qvp_flutter/qvp_flutter.dart';

import '../../../../quran/domain/models/mushaf_token_models.dart';
import '../../../../quran/domain/models/quran_refs.dart';
import '../../domain/quran_engine/quran_engine_mushaf_backend.dart';
import '../../domain/quran_engine_ref_adapter.dart';
import '../../presentation/mushaf_token_hit_rect.dart';

/// Android implementation of [QuranEngineMushafBackend], promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`lib/features/quran_engine_poc/data/quran_engine_android_adapter.dart`,
/// now historical) to production quality: hits translate through the
/// shared [QuranEngineRefAdapter] and canonical [WordRef]/[VerseRef]
/// instead of the POC's own experimental key type, and every hit is
/// reported as Tahfeez's real [MushafTokenHitRect] — the same type the
/// (now-removed) QPC V2 renderer used to report, so `MushafPager`/
/// `MushafPageView` never needed a Quran-Engine-specific code path.
///
/// Wraps `qvp_flutter` (pub.dev, v0.2.2, a `dart:ffi` plugin) directly —
/// this never reimplements rendering or hit-testing: [QuranEngineAndroidPage
/// .buildView] returns `qvp_flutter`'s own `QvpPageView` widget, which
/// already draws Quran Engine's real path geometry and resolves gap-aware
/// hit-testing natively.
///
/// Page bytes come from [quranEnginePageAssetPath] —
/// `assets/quran/quran_engine/pages/{page}.qvp`, the full 604-page corpus.
/// **This is now loaded in every build, including release, by explicit
/// product decision** — the page corpus's KFGQPC redistribution status
/// remains unresolved (same open question the former QPC V2 renderer's own
/// fonts carried; see `docs/QURAN_ENGINE_MIGRATION.md`'s licensing
/// section), and this decision does not change that legal status. There is
/// deliberately no `kReleaseMode` refusal here any more.
class QuranEngineAndroidBackend implements QuranEngineMushafBackend {
  QvpEngine? _engine;

  QvpEngine get _requireEngine {
    final engine = _engine;
    if (engine == null) {
      throw StateError(
        'QuranEngineAndroidBackend.initialize() must complete before use.',
      );
    }
    return engine;
  }

  @override
  Future<String> initialize() async {
    final engine = QvpEngine.open();
    _engine = engine;
    return '${engine.engineName} v${engine.version} (Android, dart:ffi)';
  }

  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async {
    final assetPath = quranEnginePageAssetPath(pageNumber);
    final data = await rootBundle.load(assetPath);
    final page = _requireEngine.loadPage(data.buffer.asUint8List());
    return QuranEngineAndroidPage(pageNumber: pageNumber, page: page);
  }

  @override
  void disposePage(QuranEngineMushafPage page) => page.dispose();

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {
    // No-op: pages are bundled local assets (`rootBundle.load`), not
    // fetched over a network transport with a per-page cost worth
    // hiding — unlike the Web backend, there is nothing useful to warm.
  }
}

/// The asset path Quran Engine's own `.qvp` page corpus lives at — the one
/// place this path is ever constructed. `page.toString().padLeft(3, '0')`
/// matches the vendored corpus's own filename convention
/// (`tool/quran_engine/fetch_page_data.sh`).
String quranEnginePageAssetPath(int pageNumber) =>
    'assets/quran/quran_engine/pages/${pageNumber.toString().padLeft(3, '0')}.qvp';

class QuranEngineAndroidPage implements QuranEngineMushafPage {
  QuranEngineAndroidPage({required this.pageNumber, required this.page});

  /// Left at `QvpViewLayout`'s own natural default (`1`, the printed
  /// page's original line pitch) — `qvp_flutter` clamps below `1`, so
  /// spacing only ever opens up from here, never tightens, but opening it
  /// up turns out to have a real, measured cost worth recording. This was
  /// briefly `1.15` (a "modest increase" for legibility); a real, on
  /// -device measurement (`kDebugMushafLayout`, see
  /// `docs/QURAN_ENGINE_MIGRATION.md`'s own notes) traced a persistent,
  /// otherwise-unexplained rendering gap on every side of the page
  /// directly to that change: inflating line pitch makes the engine's
  /// *laid-out* content taller at any given width-driven scale, and once
  /// that laid-out height exceeds the available viewport height, the
  /// engine shrinks the *whole page* down to compensate — smaller on
  /// every axis, not just taller lines — which is exactly backwards from
  /// what "increase line spacing a bit" was meant to achieve. Measured
  /// directly: at `1.15`, `fitScale` was `0.8875` (smaller than either
  /// axis's own individual fit scale, ~1.13); at `1.0`, `fitScale` is
  /// exactly `1.0` and the gap roughly halves. `QvpViewLayout`/
  /// `QvpLayoutSpec` (the published `qvp_flutter` v0.2.2 API, and the FFI
  /// struct it wraps — checked directly, not assumed) exposes no
  /// equivalent *word*-spacing control regardless: word/glyph positions
  /// within a line come from the page's own pre-computed printed
  /// -justification path geometry, not a re-flowable text layout, so
  /// there was never anything to widen independently of the whole line.
  static const _lineSpacing = 1.0;

  /// `QvpViewLayout`'s own defaults (`padSide: 16, padTop/padBottom: 24`)
  /// are a deliberate inset the *widget* adds around the whole page before
  /// fitting it into the viewport — separate from, and in addition to, the
  /// printed page's own authentic margins baked into its geometry. Zeroed:
  /// this is a fixed-aspect facsimile, not reflowable text, so this inset
  /// was never protecting anything — it only shrank the page inside
  /// whatever box it was already correctly fitted to.
  static const _padSide = 0.0;
  static const _padTopBottom = 0.0;

  /// Removes `QvpPageView`'s own built-in ceiling on how much wider than
  /// the page's natural print width it will ever draw — normally capped
  /// at 15% over that natural width (`QvpDefaults.aspectSlack`, 1.15),
  /// via `QvpViewLayout.maxAspectSlack`, a field `third_party/qvp_flutter`
  /// patches in (see that directory's `PATCHES.md` for the full record:
  /// this ceiling turned out to be a widget-level default with no
  /// override, not an engine limitation — the engine's own lower-level
  /// `QvpLayoutSpec.maxAspectSlack` already documents `0` as "no bound"
  /// and already honors it with no Dart-side involvement beyond passing
  /// the number through). `0` here means the engine computes the true
  /// maximum uniform scale that keeps the whole page visible within
  /// whatever box this widget is given — never more than that (the page
  /// is never stretched unevenly, never cropped), just no longer held
  /// back to within 15% of its printed size on a viewport shaped
  /// differently than the page itself. Any leftover empty space beyond
  /// this point is the real, unavoidable consequence of the page's own
  /// printed aspect ratio differing from the device's, not an artificial
  /// limit Tahfeez is imposing.
  static const _maxAspectSlack = 0.0;

  final QvpPage page;

  @override
  final int pageNumber;

  @override
  double get aspectRatio => page.width / page.height;

  @override
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
  }) {
    return QvpPageView(
      page: page,
      paper: paper,
      defaultInk: ink,
      layout: const QvpViewLayout(
        lineSpacing: _lineSpacing,
        padSide: _padSide,
        padTop: _padTopBottom,
        padBottom: _padTopBottom,
        maxAspectSlack: _maxAspectSlack,
      ),
      // `QvpPageView` defaults to `panZoomEnabled: true` — a drag *anywhere*
      // on the widget, including the empty letterboxed space around the
      // fitted page (still part of its hit-test area even though nothing
      // is drawn there), pans the rendered page content itself, separate
      // from and conflicting with `MushafPager`'s own `PageView` swipe
      // -to-turn-page gesture. Tahfeez has never offered pan/zoom as a
      // Mushaf-mode feature (nothing in `docs/QURAN_ENGINE_MIGRATION.md`'s
      // API surface assumes it, and there is no "reset view" affordance if
      // a reader pans it off-center by accident) — every page should
      // always render fully fit-to-screen. Disabled outright, not worked
      // around.
      panZoomEnabled: false,
      onWordTap: onWordHit == null
          ? null
          : (word, hit) {
              final rawKey = hit.wordKey;
              if (rawKey == null) return;
              final ref = QuranEngineRefAdapter.wordRefFromEngineKey(rawKey);
              onWordHit(
                MushafTokenHitRect(
                  // Quran Engine owns hit-testing/geometry entirely on
                  // Android (`QvpPageView` never exposes a widget-local
                  // rect for a resolved hit) — `rect`/`sourceTokenId` are
                  // QPC-V2-renderer-specific fields no caller of this
                  // backend's hits actually reads (`MushafPager
                  // ._showWordInfo` only uses `tokenType`/
                  // `canonicalAyahId`/`canonicalWordIndex`); real,
                  // meaningful values go in those three fields, not these.
                  rect: Rect.zero,
                  sourceTokenId: word,
                  tokenType: MushafTokenType.quranWord,
                  canonicalAyahId: ref.ayahId,
                  canonicalWordIndex: ref.wordIndex,
                  text: '',
                ),
              );
            },
      onDecorationTap: onDecorationHit == null
          ? null
          : (decoration) => onDecorationHit(
              MushafTokenHitRect(
                rect: Rect.zero,
                sourceTokenId: decoration.index,
                tokenType: MushafTokenType.otherMarker,
                canonicalAyahId: null,
                canonicalWordIndex: null,
                text: decoration.text,
              ),
            ),
      onEmptyTap: onEmptyHit,
    );
  }

  @override
  int highlightWord(WordRef target, {String mode = 'band'}) => page.highlight(
    T.word(_engineWordIndexOf(target)),
    QvpHighlightStyle(mode: mode),
  );

  @override
  int highlightAyah(VerseRef target, {String mode = 'band'}) => page.highlight(
    T.ayah(target.chapterNo, target.verseNo),
    QvpHighlightStyle(mode: mode),
  );

  @override
  void clearHighlights() => page.clearHighlights();

  @override
  void maskWord(WordRef target, {String mode = 'hide'}) =>
      page.mask(T.word(_engineWordIndexOf(target)), mode);

  @override
  void maskAyah(VerseRef target, {String mode = 'hide'}) =>
      page.mask(T.ayah(target.chapterNo, target.verseNo), mode);

  @override
  void revealNext([int count = 1]) {
    var position = page.revealPosition();
    if (position == null) {
      page.revealStart();
      position = page.revealPosition() ?? 0;
    }
    final total = page.revealStepCount();
    page.revealGoto((position + count).clamp(0, total));
  }

  @override
  void unmask() => page.unmask();

  @override
  void dispose() => page.dispose();

  /// [T.word] expects the engine's own page-local word-array index — not
  /// the same number as a [WordRef.wordIndex] (word-in-ayah). Resolved via
  /// the engine's own `findWord`, which is exactly what it exists for.
  int _engineWordIndexOf(WordRef ref) {
    final surahNo = ref.ayahId ~/ 1000;
    final ayahNo = ref.ayahId % 1000;
    final index = page.findWord(surahNo, ayahNo, ref.wordIndex + 1);
    if (index < 0) {
      throw StateError(
        'Word $ref (surah $surahNo, ayah $ayahNo, word ${ref.wordIndex + 1}) '
        'was not found on Quran Engine page ${page.page}.',
      );
    }
    return index;
  }
}
