import 'package:flutter/material.dart';

/// Builds Tahfeez's UI [TextTheme].
///
/// Per `docs/DESIGN_DIRECTION.md`, **UI typography and Quran typography are
/// separate systems** — this text theme is for application chrome only
/// (app bars, cards, buttons, settings, body copy). Canonical Quran Arabic
/// text must never be rendered with this theme; it will use a dedicated
/// script/font/rendering pipeline introduced in the Mushaf/Reader milestones
/// (see `docs/reference/05_MUSHAF_SPEC.md`).
///
/// The size hierarchy mirrors `docs/DESIGN_DIRECTION.md`'s suggested scale:
/// display 32-36, page title 26-30, section title 18-20, card title 16-18,
/// body 14-16, metadata 12-13. The concrete font family is intentionally
/// left as the platform default here; Milestone 3 (Design System) selects
/// Tahfeez's actual UI typeface without needing to change this mapping.
TextTheme buildAppTextTheme(ColorScheme scheme) {
  final base = Typography.material2021(colorScheme: scheme).black
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}
