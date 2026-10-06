import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_surface_tone.dart';
import '../../mushaf/domain/mushaf_appearance.dart';

/// The app's themes, as one choice each: a theme mode and a surface tone.
enum AppThemeChoice {
  system(ThemeMode.system, AppSurfaceTone.standard),
  light(ThemeMode.light, AppSurfaceTone.standard),
  warm(ThemeMode.light, AppSurfaceTone.warm),
  sepia(ThemeMode.light, AppSurfaceTone.sepia),
  dark(ThemeMode.dark, AppSurfaceTone.standard),
  black(ThemeMode.dark, AppSurfaceTone.black);

  const AppThemeChoice(this.mode, this.tone);

  final ThemeMode mode;
  final AppSurfaceTone tone;

  /// The choice [mode] and [tone] make (a tone that doesn't belong to the
  /// mode's brightness counts as standard).
  static AppThemeChoice of(ThemeMode mode, AppSurfaceTone tone) {
    for (final c in values) {
      if (c.mode == mode && c.tone == tone) return c;
    }
    return switch (mode) {
      ThemeMode.system => system,
      ThemeMode.light => light,
      ThemeMode.dark => dark,
    };
  }

  String label(AppLocalizations l10n) => switch (this) {
    system => l10n.settingsThemeSystem,
    light => l10n.settingsThemeLight,
    warm => l10n.settingsThemeWarm,
    sepia => l10n.settingsThemeSepia,
    dark => l10n.settingsThemeDark,
    black => l10n.settingsThemeBlack,
  };
}

/// A Mushaf page appearance's name in the UI language.
String mushafAppearanceName(MushafAppearance a, AppLocalizations l10n) =>
    switch (a) {
      MushafAppearance.light => l10n.settingsThemeLight,
      MushafAppearance.warm => l10n.settingsThemeWarm,
      MushafAppearance.sepia => l10n.settingsThemeSepia,
      MushafAppearance.dark => l10n.settingsThemeDark,
      MushafAppearance.black => l10n.settingsThemeBlack,
    };

/// A small round swatch: [paper] with a dot of [ink].
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.paper, required this.ink});

  final Color paper, ink;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: paper,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
    ),
  );
}
