import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_providers.dart';
import 'meaning_defaults.dart';

part 'tafsir_selection_controller.g.dart';

const _activeTafsirIdPrefKey = 'tafsir.active_id';
const _tafsirTextScalePrefKey = 'tafsir.text_scale';

/// The single active tafsir, `null` when none is selected — matches
/// `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5's single-select tafsir
/// behavior (distinct from translations' multi-select). Mirrors
/// `WbwSelectedPackController`'s exact shape
/// (`lib/wbw/application/wbw_preferences_controller.dart`).
@Riverpod(keepAlive: true)
class TafsirSelectionController extends _$TafsirSelectionController {
  @override
  String? build() {
    _restore();
    // Until a choice is made: the default for the user's language.
    return defaultTafsirId(meaningLanguage(ref));
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_activeTafsirIdPrefKey);
    if (stored == null || !ref.mounted) return;
    // '' is a chosen "none".
    final chosen = stored.isEmpty ? null : stored;
    if (chosen != state) state = chosen;
  }

  /// [tafsirId] `null` for none — kept as a choice, unlike never choosing.
  Future<void> select(String? tafsirId) async {
    state = tafsirId;
    await ref
        .read(browserStorageProvider)
        .setString(_activeTafsirIdPrefKey, tafsirId ?? '');
  }
}

/// The tafsir reader's text-size multiplier — this milestone's "adjustable
/// text size" requirement. `1.0` is the base size; the tafsir reader screen
/// multiplies its body text style by this value.
@Riverpod(keepAlive: true)
class TafsirTextScaleController extends _$TafsirTextScaleController {
  @override
  double build() {
    _restore();
    return 1.0;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_tafsirTextScalePrefKey);
    final parsed = stored == null ? null : double.tryParse(stored);
    if (parsed != null && parsed != state) {
      state = parsed;
    }
  }

  Future<void> setScale(double scale) async {
    state = scale;
    await ref
        .read(browserStorageProvider)
        .setString(_tafsirTextScalePrefKey, scale.toString());
  }
}
