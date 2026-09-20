import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:qvp_flutter/qvp_flutter.dart';

import '../../../../quran/domain/models/mushaf_token_models.dart';
import '../../../../quran/domain/models/quran_refs.dart';
import '../../domain/quran_engine/quran_engine_mushaf_backend.dart';
import '../../domain/quran_engine_ref_adapter.dart';
import '../../presentation/mushaf_page_render_model.dart';

/// Android implementation of [QuranEngineMushafBackend], promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`lib/features/quran_engine_poc/data/quran_engine_android_adapter.dart`,
/// now historical) to production quality: hits translate through the
/// shared [QuranEngineRefAdapter] and canonical [WordRef]/[VerseRef]
/// instead of the POC's own experimental key type, and every hit is
/// reported as Tahfeez's real [MushafTokenHitRect] — the same type
/// `MushafPager`/`MushafPageView` already consume for the QPC V2 renderer,
/// so neither of those files needs a Quran-Engine-specific code path.
///
/// Wraps `qvp_flutter` (pub.dev, v0.2.2, a `dart:ffi` plugin) directly —
/// this never reimplements rendering or hit-testing: [QuranEngineAndroidPage
/// .buildView] returns `qvp_flutter`'s own `QvpPageView` widget, which
/// already draws Quran Engine's real path geometry and resolves gap-aware
/// hit-testing natively.
///
/// Page bytes come from [quranEnginePageAssetPath] —
/// `assets/quran/quran_engine/pages/{page}.qvp` — gated the exact same way
/// every other KFGQPC-derived Mushaf resource in this codebase is gated
/// (see `docs/QURAN_DATA_PROVENANCE.md`'s release checklist): not declared
/// in a release build's asset list, refused in `kReleaseMode`. Quran
/// Engine's own page corpus carries the same unresolved KFGQPC
/// redistribution status as Tahfeez's existing QPC V2 fonts — adopting
/// this backend does not by itself clear that gap. See
/// `docs/QURAN_ENGINE_MIGRATION.md` §Licensing.
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
    if (kReleaseMode) {
      throw QuranEngineReleaseModeBlockedException(pageNumber);
    }
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
