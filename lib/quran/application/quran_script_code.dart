import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_providers.dart';

part 'quran_script_code.g.dart';

const _selectedScriptCodePrefKey = 'quran.selected_script_code';

/// The script every Quran-text-rendering feature (the verse-by-verse
/// Reader, the Mushaf renderer, the Quran index's Page tab) resolves
/// words/Mushafs in, if the user has never chosen one.
///
/// This used to be duplicated as `defaultQuranScriptCode` in
/// `lib/features/quran/application/quran_index_providers.dart` and
/// `defaultReaderScriptCode` in
/// `lib/features/reader/application/reader_session_controller.dart`
/// independently; once a third feature (Mushaf, Milestone 7) needed the
/// identical concept, it was consolidated here — the same
/// "shared-by-more-than-one-feature belongs in `quran/application`"
/// pattern `docs/ARCHITECTURE.md` §11c/§11d already established for
/// `hasInstalledQuranDataset` and `RecentQuranLocationController`.
const defaultQuranScriptCode = 'uthmani';

/// The user's selected Quran script, persisted like `MushafAppearanceController`
/// (`lib/features/mushaf/application/mushaf_appearance_controller.dart`) —
/// this milestone's "scripts are swappable without UI rewrites" requirement
/// made real: every Reader/Mushaf session already resolves words through
/// [quranScriptCodeProvider] rather than the [defaultQuranScriptCode]
/// constant directly, so changing this controller's state is immediately
/// visible everywhere without any per-feature code change.
///
/// No Settings screen hosts a picker for this yet (Settings/Localization is
/// Milestone 14) — Milestone 8 exposes it from the Reader's own options
/// sheet instead, the same "real preference before its eventual Settings
/// home exists" pattern already used by `ReaderModePreferenceController`.
@Riverpod(keepAlive: true)
class QuranScriptPreferenceController
    extends _$QuranScriptPreferenceController {
  @override
  String build() {
    _restore();
    return defaultQuranScriptCode;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_selectedScriptCodePrefKey);
    if (stored != null && stored != state) {
      state = stored;
    }
  }

  Future<void> setScriptCode(String scriptCode) async {
    state = scriptCode;
    await ref
        .read(browserStorageProvider)
        .setString(_selectedScriptCodePrefKey, scriptCode);
  }
}

/// A provider (rather than every reader of the selected script using
/// [QuranScriptPreferenceController] directly) so tests can override which
/// script a session loads with a plain value — necessary because
/// `QuranRepository.getVerseRangeWithWords`/`getWordsForPage` return zero
/// words outright for a script code that matches no installed `QuranScript`
/// row (not "words with empty text"), so a fixture using a different script
/// code than the production default would otherwise make every test see
/// empty content regardless of what data actually exists.
@riverpod
String quranScriptCode(Ref ref) =>
    ref.watch(quranScriptPreferenceControllerProvider);
