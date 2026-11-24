import 'package:flutter/foundation.dart' show kIsWeb;
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
ThemeData buildTahfeezTheme(
  ColorScheme scheme, {
  ArabicUiFont arabicFont = ArabicUiFont.kufi,
}) {
  scheme = _firmerContainers(scheme);
  final textTheme = buildTahfeezTextTheme(scheme, arabic: arabicFont);
  final light = scheme.brightness == Brightness.light;
  // A light sheet's paper: the surface (its tone) brought near white.
  final lightSheet = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.7),
    scheme.surface,
  );
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
    // Glass: the paper a little see-through (each sheet blurs what is
    // behind it — GlassSheet), a bright hairline along its top. In a
    // browser, which cannot blur the Mushaf's pages: opaque.
    bottomSheetTheme: BottomSheetThemeData(
      // Light themes (owner, 2026-11-24: "silver grey"): whiter paper,
      // opaque — the dim behind came through it, and the blur drew it into
      // the sheet's top as a grey band (GlassSheet doesn't blur opaque
      // paper) — and no tint of the theme's colour.
      backgroundColor: light
          ? lightSheet
          : kIsWeb
          ? scheme.surface
          : scheme.surface.withValues(alpha: 0.86),
      modalBackgroundColor: light ? lightSheet : null,
      surfaceTintColor: Colors.transparent,
      shape: sheetShape.copyWith(
        side: BorderSide(
          color: scheme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.8),
        ),
      ),
      elevation: TahfeezElevation.high,
      modalElevation: TahfeezElevation.high,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TahfeezRadii.lg),
      ),
      elevation: TahfeezElevation.medium,
      // In a browser, a dialog a normal width on a wide window too
      // (Material's own goes to 560, its text spread wide — owner,
      // 2026-11-16: "Reset all data" too wide). The apps keep theirs.
      constraints: kIsWeb
          ? const BoxConstraints(minWidth: 280, maxWidth: 400)
          : null,
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

/// Light themes: the tonal containers (a tonal button's fill — "Start
/// another", "Start with Al-Fatiha", the + buttons —, a selected chip's) a
/// firmer tint of the theme's colour (owner, 2026-11-24: the pale green was
/// lost on the page), their text a deep shade of it. Dark themes as ever.
ColorScheme _firmerContainers(ColorScheme scheme) {
  if (scheme.brightness != Brightness.light) return scheme;
  final fill = Color.alphaBlend(
    scheme.primary.withValues(alpha: 0.34),
    Colors.white,
  );
  final ink = Color.lerp(scheme.primary, Colors.black, 0.4)!;
  return scheme.copyWith(
    primaryContainer: fill,
    onPrimaryContainer: ink,
    secondaryContainer: fill,
    onSecondaryContainer: ink,
  );
}
