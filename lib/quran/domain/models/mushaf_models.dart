import 'package:freezed_annotation/freezed_annotation.dart';

part 'mushaf_models.freezed.dart';

/// What kind of content one printed [MushafLine] holds.
///
/// Named independently of the reference app's own vocabulary
/// (`docs/reference/05_MUSHAF_SPEC.md` §2 uses `surah_name`/`basmallah`/
/// `ayah`) — same three concepts, Tahfeez's own names.
enum MushafLineType { surahHeader, bismillah, quranText }

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
  }) = _Mushaf;
}

/// One physical printed line: which [Mushaf], which page, which line number
/// on that page, and exactly which words it spans.
///
/// [startAyahId]/[startWordIndex] and [endAyahId]/[endWordIndex] are `null`
/// only for a pure [MushafLineType.surahHeader] or
/// [MushafLineType.bismillah] line that carries no verse text of its own.
/// A single verse may begin, span, or end mid-line — that is exactly what
/// this start/end pair captures, per
/// `docs/reference/05_MUSHAF_SPEC.md` §2.
@freezed
abstract class MushafLine with _$MushafLine {
  const factory MushafLine({
    required int mushafId,
    required int pageNumber,
    required int lineNumber,
    required MushafLineType lineType,
    required bool isCentered,
    int? startAyahId,
    int? startWordIndex,
    int? endAyahId,
    int? endWordIndex,

    /// Denormalized chapter number, populated for [MushafLineType.surahHeader]
    /// lines so a chapter-heading line can be rendered without resolving an
    /// ayah reference first.
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
