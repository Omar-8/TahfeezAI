import '../models/quran_refs.dart';
import '../models/tafsir_models.dart';

/// Read/manage access to installed tafsir content.
///
/// See `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5. Exactly one
/// tafsir is active at a time (`quran/application/tafsir_selection_controller.dart`'s
/// `TafsirSelectionController`), matching the reference app's single-select
/// tafsir behavior — a deliberate scope decision, not this repository's
/// concern either way.
///
/// Implemented against Drift by `DriftTafsirRepository`
/// (`lib/quran/data/repositories/drift_tafsir_repository.dart`), backed by
/// its own database (`lib/quran/data/tafsir_database.dart`), physically
/// separate from the immutable canonical `QuranDatabase`.
abstract class TafsirRepository {
  Future<List<TafsirWork>> getInstalledTafsirs();

  Future<TafsirWork?> getInstalledTafsir(String tafsirId);

  /// Installs (or updates in place) [work] with its [verses] — checksum-
  /// verified before any existing installed data for [work] is touched; see
  /// [TranslationRepository.installTranslation]'s doc comment for the exact
  /// same guarantee applied to tafsir.
  Future<void> installTafsir(TafsirWork work, List<TafsirVerseText> verses);

  Future<void> deleteTafsir(String tafsirId);

  Future<TafsirVerseText?> getVerseText(
    VerseRef verse, {
    required String tafsirId,
  });
}
