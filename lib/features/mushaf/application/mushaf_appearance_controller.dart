import 'dart:ui' show Brightness;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/mushaf_appearance.dart';

part 'mushaf_appearance_controller.g.dart';

const _mushafAppearancePrefKey = 'mushaf.appearance';

/// The persisted reader-appearance preference (Light/Warm/Sepia/Dark/
/// Black), independent of the application's own theme mode — the same
/// `BrowserStorage`-backed pattern `ThemeModeController`
/// (`core/theme/theme_controller.dart`) established. With no stored
/// preference yet (a fresh install, or a fresh browser profile on web),
/// defaults to whichever of [MushafAppearance.light]/[MushafAppearance.dark]
/// matches the device's current system brightness — this project treats
/// light and dark mode as equally first-class
/// (`docs/DESIGN_DIRECTION.md`), so a device already in dark mode should
/// not have to fight through a bright Mushaf page before finding the
/// Appearance sheet. Read via [WidgetsBinding.instance] (not `dart:ui`'s
/// `PlatformDispatcher.instance` directly, which bypasses
/// `TestWidgetsFlutterBinding`'s test-brightness override and would make
/// this undetectably wrong under test) once, here, rather than kept live:
/// unlike [ThemeModeController]'s [ThemeMode.system] (a real,
/// always-reactive third state Flutter's own `MaterialApp` resolves
/// continuously), [MushafAppearance] has no such live-system variant —
/// unifying the two would be a bigger, separate change from "the initial
/// default should match the system".
@Riverpod(keepAlive: true)
class MushafAppearanceController extends _$MushafAppearanceController {
  @override
  MushafAppearance build() {
    _restore();
    final isSystemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    return isSystemDark ? MushafAppearance.dark : MushafAppearance.light;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_mushafAppearancePrefKey);
    for (final appearance in MushafAppearance.values) {
      if (appearance.name == stored && appearance != state) {
        state = appearance;
        return;
      }
    }
  }

  Future<void> setAppearance(MushafAppearance appearance) async {
    state = appearance;
    await ref
        .read(browserStorageProvider)
        .setString(_mushafAppearancePrefKey, appearance.name);
  }
}
