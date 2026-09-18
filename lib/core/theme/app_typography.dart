import 'package:flutter/material.dart';

/// Tahfeez's chosen UI typeface family names, matching the `family:` entries
/// registered in `pubspec.yaml`'s `flutter.fonts` section. See
/// `docs/THIRD_PARTY_RESOURCES.md` for licensing (both are SIL Open Font
/// License 1.1, bundled locally so the app never depends on network access
/// to render its own UI — required by this project's offline-first
/// posture).
const kTahfeezUiFontFamily = 'Noto Sans';
const kTahfeezUiFontFamilyArabic = 'Noto Sans Arabic';

/// Builds Tahfeez's UI [TextTheme].
///
/// Per `docs/DESIGN_DIRECTION.md`, **UI typography and Quran typography are
/// separate systems** — this text theme is for application chrome only
/// (app bars, cards, buttons, settings, body copy). Canonical Quran Arabic
/// text must never be rendered with this theme; it will use a dedicated
/// script/font/rendering pipeline introduced in the Mushaf/Reader milestones
/// (see `docs/reference/05_MUSHAF_SPEC.md`).
///
/// The UI typeface is Noto Sans, with Noto Sans Arabic registered as a
/// [TextStyle.fontFamilyFallback] — Flutter automatically falls back to it
/// per-glyph, so a single UI string mixing Latin and Arabic characters (a
/// translator's name, a bilingual label) renders both scripts in their
/// intended, visually-matched typeface without the app needing to detect
/// script itself. Both are variable fonts, so every [FontWeight] below maps
/// onto the same bundled file rather than needing a separate asset per
/// weight.
///
/// The size hierarchy mirrors `docs/DESIGN_DIRECTION.md`'s suggested scale:
/// display 32-36, page title 26-30, section title 18-20, card title 16-18,
/// body 14-16, metadata 12-13.
TextTheme buildTahfeezTextTheme(ColorScheme scheme) {
  final base = Typography.material2021(colorScheme: scheme).black
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  TextStyle style(
    TextStyle? from, {
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return (from ?? const TextStyle()).copyWith(
      fontFamily: kTahfeezUiFontFamily,
      fontFamilyFallback: const [kTahfeezUiFontFamilyArabic],
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  return base.copyWith(
    displayLarge: style(
      base.displayLarge,
      fontSize: 36,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: style(
      base.displayMedium,
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: style(
      base.headlineLarge,
      fontSize: 30,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: style(
      base.headlineMedium,
      fontSize: 26,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: style(
      base.titleLarge,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: style(
      base.titleMedium,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: style(
      base.titleSmall,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: style(base.bodyLarge, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: style(
      base.bodyMedium,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: style(base.bodySmall, fontSize: 13, fontWeight: FontWeight.w400),
    labelLarge: style(
      base.labelLarge,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: style(
      base.labelMedium,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: style(
      base.labelSmall,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}
