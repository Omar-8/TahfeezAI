import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'tahfeez_elevation.dart';
import 'tahfeez_theme_families.dart';

/// Assembles Tahfeez's [ThemeData] from the design tokens in this package,
/// for a given resolved [ColorScheme] — either a [TahfeezThemeFamily]'s own
/// scheme or an OS-provided dynamic scheme (see `lib/app/app.dart`, which
/// resolves which one applies before calling this). This is the single
/// place feature code should never need to reach past — everything here is
/// already channelled through [ColorScheme], [TextTheme], and
/// [TahfeezColorTokens], and every shape/elevation value below comes from a
/// shared token rather than a locally-invented number.
ThemeData buildTahfeezTheme(ColorScheme scheme) {
  final textTheme = buildTahfeezTextTheme(scheme);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(TahfeezRadii.md),
  );
  final sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TahfeezRadii.lg)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: TahfeezElevation.none,
      shape: cardShape,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: TahfeezElevation.none,
      scrolledUnderElevation: TahfeezElevation.medium,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: sheetShape,
      elevation: TahfeezElevation.high,
      modalElevation: TahfeezElevation.high,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TahfeezRadii.lg),
      ),
      elevation: TahfeezElevation.medium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        ),
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

/// Convenience for the default family — used by tests and anywhere a full
/// [TahfeezThemeFamily]/dynamic-color resolution isn't needed.
ThemeData buildLightTheme() =>
    buildTahfeezTheme(TahfeezThemeFamily.emerald.colorScheme(Brightness.light));

ThemeData buildDarkTheme() =>
    buildTahfeezTheme(TahfeezThemeFamily.emerald.colorScheme(Brightness.dark));
