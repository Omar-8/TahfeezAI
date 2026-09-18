import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A curated Tahfeez accent theme.
///
/// `docs/DESIGN_DIRECTION.md`'s light/dark exploration palette (emerald/teal
/// primary, warm gold accent) is [emerald] — Tahfeez's default. The other
/// six are independently chosen seed colors for users who prefer a
/// different accent, matching this milestone's "Provide Tahfeez color
/// families" requirement. None of these hues, names, or values are copied
/// from the reference app's own preset-theme roster
/// (`docs/reference/18_VISUAL_REFERENCE_NOTES.md` §8 explicitly flags that
/// roster as reference-only) — they are Tahfeez-original choices.
enum TahfeezThemeFamily {
  /// Deep emerald/teal — Tahfeez's default identity color.
  emerald(seedColor: Color(0xFF176B5B)),

  /// A calm, clear azure blue.
  blue(seedColor: Color(0xFF1B6FA8)),

  /// A warm, deep wine red.
  burgundy(seedColor: Color(0xFF8B2942)),

  /// A true, magenta-leaning purple.
  purple(seedColor: Color(0xFF7A4FA0)),

  /// A cooler, blue-leaning violet — distinct from [purple].
  violet(seedColor: Color(0xFF5B57C7)),

  /// A warm, restrained gold/sand — an amber accent promoted to a full
  /// family for users who want a warmer identity color.
  gold(seedColor: Color(0xFFA9822F)),

  /// A quiet, low-saturation neutral for users who prefer minimal color.
  monochrome(seedColor: Color(0xFF55595E));

  const TahfeezThemeFamily({required this.seedColor});

  /// The seed color Material 3's tonal palette algorithm derives every tone
  /// (including the full dark-mode scheme) from.
  final Color seedColor;

  /// Builds this family's [ColorScheme] for [brightness].
  ///
  /// [emerald] is special-cased in both brightnesses to match
  /// `docs/DESIGN_DIRECTION.md`'s explicit exploration values exactly,
  /// since that document gives concrete guidance only for the default
  /// family. Every other family — and emerald's algorithmic base — comes
  /// from `ColorScheme.fromSeed`, which computes genuinely different tonal
  /// values per brightness (not a simple inversion), satisfying
  /// `docs/DESIGN_DIRECTION.md`'s "design dark mode independently" rule at
  /// the system level.
  ColorScheme colorScheme(Brightness brightness) {
    if (this == TahfeezThemeFamily.emerald) {
      return brightness == Brightness.light
          ? buildLightColorScheme()
          : buildDarkColorScheme();
    }

    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }

  String get displayName => switch (this) {
    TahfeezThemeFamily.emerald => 'Emerald',
    TahfeezThemeFamily.blue => 'Blue',
    TahfeezThemeFamily.burgundy => 'Burgundy',
    TahfeezThemeFamily.purple => 'Purple',
    TahfeezThemeFamily.violet => 'Violet',
    TahfeezThemeFamily.gold => 'Gold',
    TahfeezThemeFamily.monochrome => 'Monochrome',
  };
}
