import 'package:freezed_annotation/freezed_annotation.dart';

part 'mushaf_models.freezed.dart';

/// What kind of content one printed [MushafLine] holds.
///
/// Named independently of the reference app's own vocabulary
/// (`docs/reference/05_MUSHAF_SPEC.md` §2 uses `surah_name`/`basmallah`/
/// `ayah`) — same three concepts, Tahfeez's own names.
enum MushafLineType { surahHeader, bismillah, quranText }

/// How a [Mushaf]'s text is actually drawn on screen.
///
/// [pageSpecificGlyphFont] describes QUL's KFGQPC V2 scheme: each page's
/// [MushafToken]s are only meaningful when rendered through that exact
/// page's own font (see `docs/QURAN_DATA_PROVENANCE.md` §8 — the same
/// numeric codepoint draws a different glyph on different pages). A future
/// plain-Unicode Mushaf source would use [unicodeText] instead, needing no
/// per-page font at all — kept as a real enum value now rather than
/// hardcoding the glyph-font assumption throughout the renderer.
enum MushafRenderingType { pageSpecificGlyphFont, unicodeText }

/// One Mushaf edition/pagination: a specific [QuranScript] (optionally
/// refined by a [QuranScriptVariant]) typeset into a fixed page/line layout.
/// Multiple Mushafs can coexist (one per script/variant a user might pick in
/// Settings, per `docs/reference/10_SETTINGS_SPEC.md`).
@freezed
abstract class Mushaf with _$Mushaf {
  const factory Mushaf({
    required int id,
    required String code,
    required int scriptId,
    int? scriptVariantId,
    required int pageCount,
    required int linesPerPage,

    /// The recitation/reading this edition is typeset for (e.g. `"Hafs"`).
    required String qiraah,

    /// The print edition this layout reproduces (e.g. `"Madinah / 1421H"`).
    required String edition,
    required MushafRenderingType renderingType,
  }) = _Mushaf;
}

/// One physical printed line: which [Mushaf], which page, which line number
/// on that page, and exactly which [MushafToken]s it spans.
///
/// [firstTokenId]/[lastTokenId] are [MushafToken.sourceTokenId] values —
/// **not** an (ayahId, wordIndex) range. A line's token range is the only
/// thing that determines its printed content; resolving those tokens into
/// canonical Quran words (for the ones that are real words) is
/// [MushafToken]'s job, never this line's. Deliberately not resolved eagerly
/// into ayah/word boundaries the way an earlier design attempted: a
/// printed line's token range is not guaranteed to contain only real
/// words (see `docs/QURAN_DATA_PROVENANCE.md` §7b's ayah-marker finding),
/// so an ayah/word-index range could not represent it without silently
/// dropping non-word tokens.
///
/// `null` only for a pure [MushafLineType.surahHeader] or
/// [MushafLineType.bismillah] line that carries no token range of its own.
@freezed
abstract class MushafLine with _$MushafLine {
  const factory MushafLine({
    required int mushafId,
    required int pageNumber,
    required int lineNumber,
    required MushafLineType lineType,
    required bool isCentered,
    int? firstTokenId,
    int? lastTokenId,

    /// Denormalized chapter number, populated for [MushafLineType.surahHeader]
    /// lines so a chapter-heading line can be rendered without resolving a
    /// token first.
    int? surahNo,
  }) = _MushafLine;
}

/// One rendered Mushaf page: its lines, in printed order (line 1 first).
@freezed
abstract class MushafPage with _$MushafPage {
  const factory MushafPage({
    required int mushafId,
    required int pageNumber,
    required List<MushafLine> lines,
  }) = _MushafPage;
}
