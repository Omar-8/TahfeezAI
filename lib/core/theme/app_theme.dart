import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles Tahfeez's light/dark [ThemeData] from the design tokens in this
/// package. This is the single place feature code should never need to
/// reach past — everything here is already channelled through
/// [ColorScheme], [TextTheme], and [TahfeezColorTokens].
ThemeData buildAppTheme(ColorScheme scheme) {
  final textTheme = buildAppTextTheme(scheme);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: cardShape,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
    extensions: [
      TahfeezColorTokens(
        mutedGold: TahfeezExplorationPalette.mutedGold,
        elevatedSurface: scheme.brightness == Brightness.dark
            ? TahfeezExplorationPalette.darkElevatedSurface
            : scheme.surface,
      ),
    ],
  );
}

ThemeData buildLightTheme() => buildAppTheme(buildLightColorScheme());

ThemeData buildDarkTheme() => buildAppTheme(buildDarkColorScheme());
