import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quran_script_code.g.dart';

/// The script every Quran-text-rendering feature (the verse-by-verse
/// Reader, the Mushaf renderer, the Quran index's Page tab) resolves
/// words/Mushafs in.
///
/// A single placeholder default, not one per feature — this used to be
/// duplicated as `defaultQuranScriptCode` in
/// `lib/features/quran/application/quran_index_providers.dart` and
/// `defaultReaderScriptCode` in
/// `lib/features/reader/application/reader_session_controller.dart`
/// independently; once a third feature (Mushaf, Milestone 7) needed the
/// identical concept, it was consolidated here — the same
/// "shared-by-more-than-one-feature belongs in `quran/application`"
/// pattern `docs/ARCHITECTURE.md` §11c/§11d already established for
/// `hasInstalledQuranDataset` and `RecentQuranLocationController`.
///
/// No script-selection preference exists yet (Settings/Localization is
/// Milestone 14).
const defaultQuranScriptCode = 'uthmani';

/// A provider (rather than every reader of [defaultQuranScriptCode] using
/// the constant directly) so tests can override which script a session
/// loads — necessary because `QuranRepository.getVerseRangeWithWords`/
/// `getWordsForPage` return zero words outright for a script code that
/// matches no installed `QuranScript` row (not "words with empty text"),
/// so a fixture using a different script code than the production default
/// would otherwise make every test see empty content regardless of what
/// data actually exists.
@riverpod
String quranScriptCode(Ref ref) => defaultQuranScriptCode;
