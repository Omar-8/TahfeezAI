import 'package:flutter/material.dart';

/// Tahfeez's initial exploration palette.
///
/// These values come from `docs/DESIGN_DIRECTION.md`'s "Light mode" and
/// "Dark mode" sections and are Tahfeez-original — independently chosen for
/// this project, not copied from any reference application. They are
/// explicitly a *starting point*: `docs/DESIGN_DIRECTION.md` says the design
/// system milestone (Milestone 3) may adjust them for contrast and
/// consistency. Foundation code should depend on the semantic [ColorScheme]
/// built from these values, not on this class directly, so Milestone 3 can
/// refine the values here without touching call sites.
abstract final class TahfeezExplorationPalette {
  // Light mode.
  static const lightBackground = Color(0xFFF7F8F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF176B5B);
  static const lightPrimaryAccent = Color(0xFF218A73);
  static const lightPrimaryContainer = Color(0xFFDCEFE8);
  static const lightText = Color(0xFF18201D);
  static const lightSecondaryText = Color(0xFF68736E);
  static const lightBorder = Color(0xFFE4E8E5);
  static const mutedGold = Color(0xFFB79A5B);

  // Dark mode — designed independently, not a simple inversion of light.
  static const darkBackground = Color(0xFF101513);
  static const darkSurface = Color(0xFF171D1A);
  static const darkElevatedSurface = Color(0xFF1D2521);
  static const darkPrimary = Color(0xFF68C6A8);
  static const darkPrimaryContainer = Color(0xFF203D34);
  static const darkText = Color(0xFFECF2EF);
  static const darkSecondaryText = Color(0xFFAAB6B0);
}

/// Semantic tokens that Material 3's [ColorScheme] has no dedicated slot for,
/// exposed as a [ThemeExtension] so widgets can read them the same way they
/// read [ColorScheme] or [TextTheme] (`Theme.of(context).extension<...>()`).
@immutable
class TahfeezColorTokens extends ThemeExtension<TahfeezColorTokens> {
  const TahfeezColorTokens({
    required this.mutedGold,
    required this.elevatedSurface,
  });

  /// The warm, restrained gold accent called for as a sparing highlight
  /// color (never a dominant one) in `docs/DESIGN_DIRECTION.md`.
  final Color mutedGold;

  /// A surface tone one step above [ColorScheme.surface], used for layered
  /// dark-mode surfaces per `docs/DESIGN_DIRECTION.md`'s "layered dark
  /// surfaces" guidance.
  final Color elevatedSurface;

  @override
  TahfeezColorTokens copyWith({Color? mutedGold, Color? elevatedSurface}) {
    return TahfeezColorTokens(
      mutedGold: mutedGold ?? this.mutedGold,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    );
  }

  @override
  TahfeezColorTokens lerp(ThemeExtension<TahfeezColorTokens>? other, double t) {
    if (other is! TahfeezColorTokens) return this;
    return TahfeezColorTokens(
      mutedGold: Color.lerp(mutedGold, other.mutedGold, t) ?? mutedGold,
      elevatedSurface:
          Color.lerp(elevatedSurface, other.elevatedSurface, t) ??
          elevatedSurface,
    );
  }
}

ColorScheme buildLightColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: TahfeezExplorationPalette.lightPrimary,
    brightness: Brightness.light,
  ).copyWith(
    primary: TahfeezExplorationPalette.lightPrimary,
    primaryContainer: TahfeezExplorationPalette.lightPrimaryContainer,
    surface: TahfeezExplorationPalette.lightSurface,
    onSurface: TahfeezExplorationPalette.lightText,
    onSurfaceVariant: TahfeezExplorationPalette.lightSecondaryText,
    outlineVariant: TahfeezExplorationPalette.lightBorder,
    tertiary: TahfeezExplorationPalette.mutedGold,
  );
}

ColorScheme buildDarkColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: TahfeezExplorationPalette.darkPrimary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: TahfeezExplorationPalette.darkPrimary,
    primaryContainer: TahfeezExplorationPalette.darkPrimaryContainer,
    surface: TahfeezExplorationPalette.darkSurface,
    onSurface: TahfeezExplorationPalette.darkText,
    onSurfaceVariant: TahfeezExplorationPalette.darkSecondaryText,
    tertiary: TahfeezExplorationPalette.mutedGold,
  );
}
