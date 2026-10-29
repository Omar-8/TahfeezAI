import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_providers.dart';

part 'wbw_preferences_controller.g.dart';

const _selectedPackIdPrefKey = 'wbw.selected_pack_id';
const _showTranslationPrefKey = 'wbw.show_translation';
const _showTransliterationPrefKey = 'wbw.show_transliteration';
const _wordAudioEnabledPrefKey = 'wbw.word_audio_enabled';

/// The installed WBW pack id the word detail sheet resolves translations
/// from, `null` when the user has never selected one (or the previously
/// selected pack has since been deleted — see `activeWbwPackProvider`,
/// which re-validates this against what is actually installed rather than
/// trusting the stored id blindly).
///
/// Persisted like `MushafAppearanceController`
/// (`lib/features/mushaf/application/mushaf_appearance_controller.dart`).
@Riverpod(keepAlive: true)
class WbwSelectedPackController extends _$WbwSelectedPackController {
  @override
  String? build() {
    _restored = _restore();
    return null;
  }

  late Future<void> _restored;

  /// Done once the stored choice is read.
  Future<void> get restored => _restored;

  /// The app's language changed from [from]: a pack chosen in [from] goes
  /// back to the language's own (`activeWbwPack`); one chosen in another
  /// language stays.
  Future<void> follow(String from) async {
    await _restored;
    if (!ref.mounted) return;
    final current = state;
    if (current != null && current.split('-').first == from) {
      await select(null);
    }
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_selectedPackIdPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> select(String? packId) async {
    state = packId;
    if (packId == null) {
      await ref.read(browserStorageProvider).remove(_selectedPackIdPrefKey);
    } else {
      await ref
          .read(browserStorageProvider)
          .setString(_selectedPackIdPrefKey, packId);
    }
  }
}

/// Whether the word detail sheet shows a word's translation, when the
/// active pack has one. On by default.
@Riverpod(keepAlive: true)
class WbwShowTranslationPreferenceController
    extends _$WbwShowTranslationPreferenceController {
  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_showTranslationPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(browserStorageProvider)
        .setBool(_showTranslationPrefKey, enabled);
  }
}

/// Whether the word detail sheet shows a word's transliteration, when the
/// active pack has one. On by default.
@Riverpod(keepAlive: true)
class WbwShowTransliterationPreferenceController
    extends _$WbwShowTransliterationPreferenceController {
  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_showTransliterationPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(browserStorageProvider)
        .setBool(_showTransliterationPrefKey, enabled);
  }
}

/// Whether the word detail sheet's "play word audio" affordance is enabled.
/// Off by default — no word-audio playback engine exists yet (Milestone
/// 12), so this preference has no real effect today beyond gating whether
/// the (always "coming soon") play affordance appears at all; a real
/// implementation wiring this to actual playback is that milestone's job.
@Riverpod(keepAlive: true)
class WbwWordAudioEnabledPreferenceController
    extends _$WbwWordAudioEnabledPreferenceController {
  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_wordAudioEnabledPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(browserStorageProvider)
        .setBool(_wordAudioEnabledPrefKey, enabled);
  }
}
