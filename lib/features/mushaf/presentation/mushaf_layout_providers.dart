import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/bismillah_text.dart';
import '../../../quran/application/quran_chapter_localization.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../application/mushaf_text_boldness_controller.dart';
import '../application/quranapp_special_font_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/mushaf_page_layout_engine.dart';
import '../domain/mushaf_text_boldness.dart';
import 'mushaf_page_render_model.dart';
import 'text_painter_word_measurer.dart';

part 'mushaf_layout_providers.g.dart';

/// The [MushafPageLayoutEngine] instance every Mushaf page in the app lays
/// out with, backed by the real [TextPainterWordMeasurer].
///
/// Lives in `presentation/`, not `application/`: the engine itself
/// (`lib/features/mushaf/domain/mushaf_page_layout_engine.dart`) is pure
/// Dart, but the concrete measurer it needs wraps Flutter's `TextPainter`
/// — a rendering concern — so wiring the two together belongs on the
/// presentation side of the `domain → application → presentation`
/// dependency direction (`docs/ARCHITECTURE.md` §1), not the other way
/// around.
///
/// A plain (non-async) provider: constructing the engine itself is trivial.
/// The actual per-page shaping work it feeds into is memoized separately —
/// see [mushafPageRenderModelProvider].
@riverpod
MushafPageLayoutEngine mushafPageLayoutEngine(Ref ref) {
  return const MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());
}

/// One page's fully-shaped [MushafPageRenderModel], memoized by every
/// value that actually changes what gets shaped: (mushafId, pageNumber,
/// availableWidth, availableHeight, fontFamily) plus whatever
/// [mushafAppearanceControllerProvider]/[mushafTextBoldnessControllerProvider]/
/// [bismillahTextProvider]/[localeControllerProvider] currently resolve to
/// (each `ref.watch`ed below, so a genuine change in any of them correctly
/// reshapes — only an *unrelated* rebuild is skipped). Watching
/// [mushafTextBoldnessControllerProvider] here — never the page-specific
/// QCF *font* provider, which has its own independent cache key that this
/// preference never touches — is exactly what makes a boldness change
/// re-shape (cheap: the same real-font `TextPainter` work every other
/// dependency here already triggers) the currently visible page
/// immediately, without ever re-loading or replacing its font.
///
/// This is the entire cost of preparing a page for paint — real font
/// shaping via `TextPainter`, once per *line* (see
/// [MushafPageLayoutEngine]'s doc comment), not once per word. Calling
/// that shaping step directly from a widget's `build`/`LayoutBuilder` — an
/// earlier design's approach — redid it on *every* rebuild of the page,
/// including ones with nothing to do with layout at all, which is a real,
/// measurable contributor to Mushaf-mode scroll jank. `keepAlive: true`
/// plus Riverpod's own family-provider caching means this only ever
/// recomputes when one of the key parts actually changes. Concurrent reads
/// for the same key are naturally deduplicated by Riverpod (one in-flight
/// computation per key, shared by every caller), and the cached result
/// survives a page scrolling back out of view (no autoDispose), so a fast
/// swipe back to an already-seen page reuses it instead of reshaping.
@Riverpod(keepAlive: true)
MushafPageRenderModel? mushafPageRenderModel(
  Ref ref, {
  required int mushafId,
  required int pageNumber,
  required double availableWidth,
  required double availableHeight,
  String? fontFamily,
}) {
  final bundle = ref.watch(mushafPageDataProvider(mushafId, pageNumber)).value;
  if (bundle == null) return null;

  final engine = ref.watch(mushafPageLayoutEngineProvider);
  final colors = ref.watch(mushafAppearanceControllerProvider).colors;
  final textBoldness = ref.watch(mushafTextBoldnessControllerProvider);
  final bismillahText = ref.watch(bismillahTextProvider).value;
  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';

  // The active special-line mechanism (docs/QURAN_DATA_PROVENANCE.md
  // §12/§13) — the QUL COLR header (surahHeaderGlyphManifestProvider) is
  // deliberately never watched here any more, kept only as an unused
  // development resource per that section.
  final quranCommonManifest = ref.watch(quranCommonFontManifestProvider).value;
  final suraconManifest = ref.watch(suraconGlyphManifestProvider).value;
  final suraconEntriesByNo = {
    for (final e in suraconManifest?.entries ?? const []) e.surahNumber: e,
  };

  final surahNosOnPage = {
    for (final line in bundle.lines)
      if (line.surahNo != null) line.surahNo!,
  };
  final surahNamesByNo = <int, String>{
    for (final surahNo in surahNosOnPage)
      surahNo:
          ref
              .watch(
                chapterLocalizationProvider(
                  surahNo,
                  languageCode: languageCode,
                ),
              )
              .value
              ?.name ??
          'Surah $surahNo',
  };

  return buildMushafPageRenderModel(
    engine: engine,
    bundle: bundle,
    availableWidth: availableWidth,
    availableHeight: availableHeight,
    fontFamily: fontFamily,
    textColor: colors.text,
    headerInkColor: colors.headerInk,
    bismillahText: bismillahText,
    quranTextStrokeWidth: strokeWidthForMushafBoldness(textBoldness),
    surahHeaderNameResolver: (surahNo) => surahNamesByNo[surahNo],
    quranCommonFontFamily: quranCommonManifest?.fontFamily,
    suraconFontFamily: suraconManifest?.fontFamily,
    suraconInputTextResolver: suraconManifest == null
        ? null
        : (surahNo) {
            final entry = suraconEntriesByNo[surahNo];
            if (entry == null) return null;
            // Name glyph first, then the shared prefix glyph -- the same
            // concatenation order QuranApp's own `ChapterIcon.kt` uses.
            return entry.inputText + suraconManifest.prefixInputText;
          },
  );
}
