import 'package:flutter/material.dart';

/// The five reader-appearance hooks `docs/DESIGN_DIRECTION.md`'s "Reader
/// themes" section calls for. Independent of the application's own
/// light/dark [ColorScheme] — per this milestone's explicit "do not let
/// application card styling leak into the Mushaf page" requirement, a
/// Mushaf page's colors come only from [MushafAppearanceColors], never from
/// `Theme.of(context)`.
enum MushafAppearance { light, warm, sepia, dark, black }

/// One appearance's page background/text colors — independently chosen
/// Tahfeez values (not copied from any reference app), the same kind of
/// "exploration palette, not final pixel values" starting point
/// `docs/DESIGN_DIRECTION.md` gave for the application theme itself.
class MushafAppearanceColors {
  const MushafAppearanceColors({
    required this.background,
    required this.text,
    required this.secondaryText,
  });

  final Color background;
  final Color text;
  final Color secondaryText;
}

extension MushafAppearanceX on MushafAppearance {
  MushafAppearanceColors get colors => switch (this) {
    MushafAppearance.light => const MushafAppearanceColors(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF1C1C1C),
      secondaryText: Color(0xFF6B6B6B),
    ),
    MushafAppearance.warm => const MushafAppearanceColors(
      background: Color(0xFFFBF1DE),
      text: Color(0xFF3B2E1E),
      secondaryText: Color(0xFF8A7355),
    ),
    MushafAppearance.sepia => const MushafAppearanceColors(
      background: Color(0xFFF0E2C6),
      text: Color(0xFF4B3A22),
      secondaryText: Color(0xFF8C7350),
    ),
    MushafAppearance.dark => const MushafAppearanceColors(
      background: Color(0xFF171D1A),
      text: Color(0xFFECF2EF),
      secondaryText: Color(0xFFAAB6B0),
    ),
    MushafAppearance.black => const MushafAppearanceColors(
      background: Color(0xFF000000),
      text: Color(0xFFE6E6E6),
      secondaryText: Color(0xFF999999),
    ),
  };

  String get label => switch (this) {
    MushafAppearance.light => 'Light',
    MushafAppearance.warm => 'Warm',
    MushafAppearance.sepia => 'Sepia',
    MushafAppearance.dark => 'Dark',
    MushafAppearance.black => 'Black',
  };
}
