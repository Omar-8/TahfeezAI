import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/mushaf_text_boldness.dart';

part 'mushaf_text_boldness_controller.g.dart';

const _mushafTextBoldnessPrefKey = 'mushaf.textBoldness';

/// The persisted Mushaf Quran-text-boldness preference — the same
/// `BrowserStorage`-backed pattern [MushafAppearanceController]
/// (`mushaf_appearance_controller.dart`) established. Unlike that
/// controller, there is no system-setting to default from here: with no
/// stored preference yet (a fresh install, or a fresh browser profile on
/// web), this always defaults to [MushafTextBoldness.medium] — the value
/// this milestone's real visual comparison judged as the smallest stroke
/// width producing a clearly perceptible improvement over the font's own
/// default rendering.
@Riverpod(keepAlive: true)
class MushafTextBoldnessController extends _$MushafTextBoldnessController {
  @override
  MushafTextBoldness build() {
    _restore();
    return MushafTextBoldness.medium;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_mushafTextBoldnessPrefKey);
    for (final value in MushafTextBoldness.values) {
      if (value.name == stored && value != state) {
        state = value;
        return;
      }
    }
  }

  Future<void> setBoldness(MushafTextBoldness value) async {
    state = value;
    await ref
        .read(browserStorageProvider)
        .setString(_mushafTextBoldnessPrefKey, value.name);
  }
}
