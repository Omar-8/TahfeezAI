import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/reader_mode.dart';

part 'reader_preferences_controller.g.dart';

const _continuousScrollingPrefKey = 'reader.continuous_scrolling';
const _arabicTextVisiblePrefKey = 'reader.arabic_text_visible';
const _readerModePrefKey = 'reader.mode';

/// Whether reaching the end of the requested reading unit (a Surah, a
/// Juz/Hizb's last chapter segment, …) should transparently continue into
/// the next chapter rather than stopping — this milestone's "continuous
/// scrolling" reading mode, modeled as a reader-wide preference rather than
/// a separate screen, since it changes what happens at the *end* of any
/// reading session rather than how one starts. On by default, matching
/// modern Quran-reader conventions. Persisted like `ThemeModeController`
/// (`core/theme/theme_controller.dart`).
@Riverpod(keepAlive: true)
class ContinuousScrollingPreferenceController
    extends _$ContinuousScrollingPreferenceController {
  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_continuousScrollingPrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(browserStorageProvider)
        .setBool(_continuousScrollingPrefKey, enabled);
  }
}

/// Whether Arabic verse text is currently shown. A real, reader-owned
/// display toggle (distinct from the future Reader Settings screen,
/// Milestone 14) — useful on its own today, and the same show/hide
/// mechanism a memorization "hide text" mode will eventually reuse.
@Riverpod(keepAlive: true)
class ArabicTextVisiblePreferenceController
    extends _$ArabicTextVisiblePreferenceController {
  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getBool(_arabicTextVisiblePrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    await ref
        .read(browserStorageProvider)
        .setBool(_arabicTextVisiblePrefKey, visible);
  }
}

/// The reader mode used for new reading sessions. Always
/// [ReaderMode.verseByVerse] today (the only implemented mode), but
/// persisted so switching modes becomes a one-controller change once
/// Mushaf/Translation modes exist (Milestones 7, 9), per this milestone's
/// "architecturally ready" requirement.
@Riverpod(keepAlive: true)
class ReaderModePreferenceController extends _$ReaderModePreferenceController {
  @override
  ReaderMode build() {
    _restore();
    return ReaderMode.verseByVerse;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_readerModePrefKey);
    for (final mode in ReaderMode.values) {
      if (mode.name == stored && mode != state) {
        state = mode;
        return;
      }
    }
  }

  Future<void> setMode(ReaderMode mode) async {
    state = mode;
    await ref
        .read(browserStorageProvider)
        .setString(_readerModePrefKey, mode.name);
  }
}
