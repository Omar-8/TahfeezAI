import 'package:drift/native.dart';
import 'package:tahfeez_ai/core/audio/audio_controller.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import 'fake_audio_controller.dart';

/// The default override set for widget tests that render `TahfeezApp` (or
/// any subtree under it) now that `HomeScreen`/`AppShell` genuinely depend
/// on `quranRepositoryProvider` and `audioControllerProvider` — the first
/// screens to do so (see `docs/ARCHITECTURE.md`'s Milestone 4 section).
///
/// Both real backends need a platform channel `flutter test` does not
/// provide (`drift_flutter`'s native SQLite path via `path_provider`;
/// `just_audio`'s real player), which otherwise leaves a `pumpAndSettle()`
/// stuck forever. This overrides `quranDatabaseProvider`/`wbwDatabaseProvider`
/// with a real in-memory `NativeDatabase` (matching
/// `test/quran/data/drift_quran_repository_test.dart`'s pattern) and
/// `audioControllerProvider` with [FakeAudioController] — real behavior
/// wherever an equivalent test-safe backend exists (Drift), a fake only
/// where none does (`just_audio`). Pass [audioController] when a test needs
/// to drive playback state directly (e.g. to simulate an active track).
///
/// No explicit return type is written here: riverpod's `Override` type
/// (`ProviderScope`/`ProviderContainer`'s `overrides` parameter type) is
/// annotated `@publicInCodegen` upstream and is not resolvable from
/// ordinary application code even though instances of it are. This must
/// stay **one** function building the list directly from `.overrideWith(…)`
/// expressions — splitting it into smaller un-annotated helper functions
/// that call each other was tried and silently produced a `List<dynamic>`
/// at runtime instead of `List<Override>` (a `strict_top_level_inference`
/// fallback that only surfaces as a runtime `TypeError` when the list is
/// handed to `ProviderScope`, not as a static analysis error).
// ignore: strict_top_level_inference
tahfeezWidgetTestOverrides({AudioController? audioController}) {
  return [
    quranDatabaseProvider.overrideWith((ref) {
      final db = QuranDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    wbwDatabaseProvider.overrideWith((ref) {
      final db = WbwDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    translationDatabaseProvider.overrideWith((ref) {
      final db = TranslationDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    tafsirDatabaseProvider.overrideWith((ref) {
      final db = TafsirDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    audioControllerProvider.overrideWith(
      (ref) => audioController ?? FakeAudioController(),
    ),
  ];
}
