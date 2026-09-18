import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_providers.dart';

part 'theme_controller.g.dart';

const _themeModePrefKey = 'core.theme_mode';

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
