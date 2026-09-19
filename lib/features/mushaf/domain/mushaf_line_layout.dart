import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../quran/domain/models/mushaf_models.dart';

part 'mushaf_line_layout.freezed.dart';

/// One word's computed position within its line.
///
/// [x] is a "reading-order offset from the line's own leading edge": `x`
/// is 0 for the first word (`wordIndex` 0 of the line's first ayah), and
/// increases in reading order for subsequent words. Since Arabic reads
/// right-to-left, the *first* word in reading order is the *rightmost* one
/// on screen — converting this reading-order offset into an actual screen
/// x-coordinate is the renderer's job
/// (`lib/features/mushaf/presentation/font_mushaf_line_painter.dart`), kept
/// out of this pure-Dart layout model so the layout math itself has no
/// notion of "screen" or "canvas."
@freezed
abstract class MushafWordPlacement with _$MushafWordPlacement {
  const factory MushafWordPlacement({
    required int ayahId,
    required int wordIndex,
    required String text,
    required double x,
    required double width,
  }) = _MushafWordPlacement;
}

/// One physical line's computed layout: a font size sized so its words —
/// together with fitted inter-word spacing — fill (or, for a centered
/// line, sit within) the available line width, plus every word's
/// placement for rendering and hit testing.
///
/// [lineWidth] is the line's actual occupied width, always `<=` the
/// `availableWidth` [MushafPageLayoutEngine.layoutLine] was given — the
/// concrete "prevent clipping" guarantee this milestone requires.
@freezed
abstract class MushafLineLayout with _$MushafLineLayout {
  const factory MushafLineLayout({
    required int lineNumber,
    required MushafLineType lineType,
    required bool isCentered,
    int? surahNo,
    required double fontSize,
    required double lineWidth,
    required List<MushafWordPlacement> placements,
  }) = _MushafLineLayout;
}

/// One page's computed layout: every line, in printed order.
@freezed
abstract class MushafPageLayout with _$MushafPageLayout {
  const factory MushafPageLayout({
    required int pageNumber,
    required List<MushafLineLayout> lines,
  }) = _MushafPageLayout;
}
