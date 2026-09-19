import 'package:flutter/material.dart';

/// Builds the text style used to render canonical Quran Arabic text.
///
/// Deliberately **not** part of [buildTahfeezTextTheme]/`app_typography.dart`
/// — per `docs/DESIGN_DIRECTION.md`'s "UI typography and Quran typography
/// are separate systems" rule, canonical Quran text must never render with
/// Tahfeez's own UI font (Noto Sans / Noto Sans Arabic). No Quran-specific
/// script/font has been selected yet — that decision belongs to the Mushaf
/// Renderer milestone (7), which must reconcile a font choice with a
/// specific Mushaf page/line dataset (`docs/DATA_RESOURCE_REQUIREMENTS.md`
/// §5). Leaving [TextStyle.fontFamily] unset here defers to each platform's
/// own default Arabic-capable system font — distinct from (and not a
/// substitute for) a real Uthmani-style Quran typeface, but also not
/// Tahfeez's branded UI font, satisfying the separation rule honestly until
/// that milestone lands.
TextStyle quranTextStyle(BuildContext context, {double fontSize = 26}) {
  return TextStyle(
    fontSize: fontSize,
    height: 1.9,
    color: Theme.of(context).colorScheme.onSurface,
  );
}
