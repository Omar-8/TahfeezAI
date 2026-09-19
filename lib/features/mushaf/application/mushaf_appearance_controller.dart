import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/mushaf_appearance.dart';

part 'mushaf_appearance_controller.g.dart';

const _mushafAppearancePrefKey = 'mushaf.appearance';

/// The persisted reader-appearance preference (Light/Warm/Sepia/Dark/
/// Black), independent of the application's own theme mode — the same
/// `BrowserStorage`-backed pattern `ThemeModeController`
/// (`core/theme/theme_controller.dart`) established. Defaults to
/// [MushafAppearance.light], matching this project's "light mode is
/// first-class" stance.
@Riverpod(keepAlive: true)
class MushafAppearanceController extends _$MushafAppearanceController {
  @override
  MushafAppearance build() {
    _restore();
    return MushafAppearance.light;
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
