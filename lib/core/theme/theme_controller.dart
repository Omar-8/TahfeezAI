import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_providers.dart';
import 'tahfeez_theme_families.dart';

part 'theme_controller.g.dart';

const _themeModePrefKey = 'core.theme_mode';
const _themeFamilyPrefKey = 'core.theme_family';
const _dynamicColorPrefKey = 'core.use_dynamic_color';

/// Persisted [ThemeMode] selection (system/light/dark).
///
/// Backed by [BrowserStorage] so the choice survives restarts identically on
/// Android, iOS, and Web. Defaults to [ThemeMode.system], matching
/// `docs/DESIGN_DIRECTION.md`'s equal investment in both light and dark
/// mode — Tahfeez should not silently default users into one over the
/// other.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_themeModePrefKey);
    for (final mode in ThemeMode.values) {
      if (mode.name == stored && mode != state) {
        state = mode;
        return;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(browserStorageProvider)
        .setString(_themeModePrefKey, mode.name);
  }
}

/// Persisted [TahfeezThemeFamily] selection. Defaults to
/// [TahfeezThemeFamily.emerald], Tahfeez's identity color.
@Riverpod(keepAlive: true)
class ThemeFamilyController extends _$ThemeFamilyController {
  @override
  TahfeezThemeFamily build() {
    _restore();
    return TahfeezThemeFamily.emerald;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_themeFamilyPrefKey);
    for (final family in TahfeezThemeFamily.values) {
      if (family.name == stored && family != state) {
        state = family;
        return;
      }
    }
  }

  Future<void> setFamily(TahfeezThemeFamily family) async {
    state = family;
    await ref
        .read(browserStorageProvider)
        .setString(_themeFamilyPrefKey, family.name);
  }
}

/// Whether to prefer the platform's dynamic (Material You) color, when the
/// platform offers one, over the selected [TahfeezThemeFamily].
///
/// Per this milestone's "support platform dynamic/system color only where
/// appropriate and optional" requirement: this defaults to `false` (a
/// curated Tahfeez family is the default identity), and is only ever
/// consulted where a dynamic scheme actually exists
/// (`TahfeezApp`/`DynamicColorBuilder` — no dynamic scheme is available on
/// iOS or the web, so this preference is a no-op there regardless of its
/// value).
@Riverpod(keepAlive: true)
class DynamicColorPreferenceController
    extends _$DynamicColorPreferenceController {
  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_dynamicColorPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(browserStorageProvider)
        .setBool(_dynamicColorPrefKey, enabled);
  }
}
