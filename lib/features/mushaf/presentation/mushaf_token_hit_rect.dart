import 'package:flutter/rendering.dart' show Rect;

import '../../../quran/domain/models/mushaf_token_models.dart';

/// One resolved word/decoration hit on a rendered Mushaf page — the shared
/// shape every rendering backend reports through, so `MushafPager`'s tap
/// handling (`_showWordInfo` → `showWordDetailSheet`) never needs to know
/// which backend actually drew the page.
///
/// Originally defined alongside the QPC V2 renderer's own render model
/// (which additionally used [rect] to recover a token's on-screen box from
/// a shaped `TextPainter`); kept here on its own now that Quran Engine is
/// the only rendering backend (`docs/QURAN_ENGINE_MIGRATION.md`) — Quran
/// Engine owns hit-testing/geometry entirely itself and does not populate
/// [rect]/[sourceTokenId] with meaningful values (`MushafPager
/// ._showWordInfo` only ever reads [tokenType]/[canonicalAyahId]/
/// [canonicalWordIndex]).
class MushafTokenHitRect {
  const MushafTokenHitRect({
    required this.rect,
    required this.sourceTokenId,
    required this.tokenType,
    required this.canonicalAyahId,
    required this.canonicalWordIndex,
    required this.text,
  });

  final Rect rect;
  final int sourceTokenId;
  final MushafTokenType tokenType;
  final int? canonicalAyahId;
  final int? canonicalWordIndex;
  final String text;
}
