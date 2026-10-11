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

  /// Al-Fatiha's page and the start of Al-Baqara print little text on a full
  /// page canvas, so it looks small next to other pages. Their text is drawn
  /// slightly larger about its own center; the page fit is unchanged.
  static const _biggerTextPages = {1, 2};
  static const _biggerTextZoom = 1.3;

  final QvpPage page;

  /// Stable across rebuilds of the same loaded page — [buildView] runs on
  /// every rebuild, and a fresh controller each time would drop any zoom
  /// applied to it.
  final QvpViewController _viewController = QvpViewController();

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
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  }) {
    final view = _buildQvpPageView(
      ink: ink,
      paper: paper,
      onWordHit: onWordHit,
      onDecorationHit: onDecorationHit,
      onEmptyHit: onEmptyHit,
      onWordLongHit: onWordLongHit,
    );
    if (!_biggerTextPages.contains(pageNumber)) return view;
    return _ZoomTextInPlace(
      page: page,
      controller: _viewController,
      zoom: _biggerTextZoom,
      child: view,
    );
  }

  Widget _buildQvpPageView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  }) {
    return QvpPageView(
      page: page,
      controller: _viewController,
      paper: paper,
      defaultInk: ink,
      layout: QvpViewLayout(
        lineSpacing: _lineSpacing,
        padSide: _padSide,
        padTop: _padTopBottom,
        padBottom: _padTopBottom,
        maxAspectSlack: _maxAspectSlack,
        // A full page's lines spread over the whole height the screen
        // gives it (no band of empty paper under the last line). The short
        // opening pages keep their own spacing (see [_biggerTextPages]).
        fillHeight: !_biggerTextPages.contains(pageNumber),
      ),
      // No drop shadow under the page: on light paper it showed as a grey
      // band below the last line; the page is the screen, not a sheet on it.
      paperShadow: false,
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
      onWordLongPress: onWordLongHit == null
          ? null
          : (word, hit) {
              final rawKey = hit.wordKey;
              if (rawKey == null) return;
              final ref = QuranEngineRefAdapter.wordRefFromEngineKey(rawKey);
              onWordLongHit(
                MushafTokenHitRect(
                  rect: Rect.zero,
                  sourceTokenId: word,
                  tokenType: MushafTokenType.quranWord,
                  canonicalAyahId: ref.ayahId,
                  canonicalWordIndex: ref.wordIndex,
                  text: '',
                ),
              );
            },
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
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) {
    // `QvpPage` is a ChangeNotifier: `QvpPageView` repaints on each call.
    page.unmask();
    if (!hidden) return;
    page.mask(T.page(), 'hide');
    if (revealedWords > 0) page.unmaskNext(revealedWords);
  }

  @override
  int get wordCount => page.words.length;

  @override
  late final List<int> ayahWordBoundaries = [
    for (var i = 1; i <= page.words.length; i++)
      if (i == page.words.length ||
          page.words[i].surah != page.words[i - 1].surah ||
          page.words[i].ayah != page.words[i - 1].ayah)
        i,
  ];

  @override
  ({VerseRef first, VerseRef last})? get verseSpan => page.words.isEmpty
      ? null
      : (
          first: (
            chapterNo: page.words.first.surah,
            verseNo: page.words.first.ayah,
          ),
          last: (
            chapterNo: page.words.last.surah,
            verseNo: page.words.last.ayah,
          ),
        );

  @override
  late final List<WordRef> wordRefs = [
    for (final w in page.words)
      (
        ayahId: QuranEngineRefAdapter.ayahIdOf(
          surahNo: w.surah,
          ayahNo: w.ayah,
        ),
        wordIndex: w.word - 1,
      ),
  ];

  @override
  void setHiddenWords(Set<int> hidden) {
    // `QvpPage` is a ChangeNotifier: `QvpPageView` repaints on each call.
    page.unmask();
    if (hidden.isEmpty) return;
    page.mask(T.page(), 'hide');
    for (var i = 0; i < page.words.length; i++) {
      if (!hidden.contains(i)) page.unmaskWord(i);
    }
  }

  @override
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights, {
    List<PageBand> bands = const [],
  }) {
    page.clearHighlights();
    // Each band fills its lines' whole slots (patch 0003): no gaps between
    // lines, however the page spreads them.
    for (final b in bands) {
      page.slotFillHighlights.add(
        page.highlight(
          b.isAyahs
              ? T.ayahRange(b.surah, b.fromAyah, b.toAyah)
              : T.words(b.words),
          QvpHighlightStyle(band: b.color),
        ),
      );
    }
    for (final h in highlights) {
      page.highlight(
        T.word(h.word),
        h.ink
            ? QvpHighlightStyle(mode: 'ink', ink: h.color)
            : QvpHighlightStyle(band: h.color),
      );
    }
  }

  @override
  int highlightWordAt(int wordIndex, {required Color color}) =>
      page.highlight(T.word(wordIndex), QvpHighlightStyle(band: color));

  @override
  void dispose() {
    _viewController.dispose();
    page.dispose();
  }

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

/// Scales a [QvpPageView]'s printed text by [zoom] about the artwork's own
/// center, leaving the page fit (and so the page's size and position in the
/// viewport) as the engine computed it. It adjusts the same
/// [QvpViewController] the view paints and hit-tests through, so word taps,
/// highlights and masks stay aligned with what is drawn.
///
/// `QvpPageView` re-fits and resets the controller whenever its size
/// changes and on double-tap, so this re-applies on a size/page change and
/// whenever the controller drifts from the target. It always starts from the
/// engine's own fit (`layout.fitScale/fitX/fitY`), so re-applying is
/// idempotent.
class _ZoomTextInPlace extends StatefulWidget {
  const _ZoomTextInPlace({
    required this.page,
    required this.controller,
    required this.zoom,
    required this.child,
  });

  final QvpPage page;
  final QvpViewController controller;
  final double zoom;
  final Widget child;

  @override
  State<_ZoomTextInPlace> createState() => _ZoomTextInPlaceState();
}

class _ZoomTextInPlaceState extends State<_ZoomTextInPlace> {
  Size? _lastSize;
  QvpPage? _lastPage;
  bool _applying = false;
  bool _scheduled = false;
  ({double scale, double x, double y})? _target;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _ZoomTextInPlace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _target = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final target = _target;
    if (_applying || target == null) return;
    final c = widget.controller;
    if ((c.scale - target.scale).abs() > 1e-3 ||
        (c.offsetX - target.x).abs() > 0.5 ||
        (c.offsetY - target.y).abs() > 0.5) {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _apply();
    });
  }

  void _apply() {
    final layout = widget.page.currentLayout;
    final art = widget.page.cropBounds(T.page(), pad: 0);
    if (layout == null || art == null) return;

    // Artwork center in layout space, and where the engine's own fit (the
    // controller's default state) puts it on screen.
    final cx = layout.offsetX + (art.x0 + art.x1) / 2 * layout.scale;
    final cy = layout.offsetY + (art.y0 + art.y1) / 2 * layout.scale;
    final baseScale = layout.fitScale;
    final vx = layout.fitX + baseScale * cx;
    final vy = layout.fitY + baseScale * cy;

    final scale = baseScale * widget.zoom;
    final x = vx - scale * cx;
    final y = vy - scale * cy;
    _target = (scale: scale, x: x, y: y);

    _applying = true;
    widget.controller.set(scale: scale, offsetX: x, offsetY: y);
    _applying = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _lastSize || !identical(widget.page, _lastPage)) {
          _lastSize = size;
          _lastPage = widget.page;
          _target = null;
          _schedule();
        }
        return widget.child;
      },
    );
  }
}
