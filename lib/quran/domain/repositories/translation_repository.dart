import '../models/quran_refs.dart';
import '../models/translation_models.dart';

/// Read/manage access to installed Quran translations.
///
/// Per `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`, more than one
/// translation may be simultaneously active; installing/removing a
/// translation is independent of selecting it for display — *which*
/// installed translations are active and in what order is a user
/// preference (`quran/application/translation_selection_controller.dart`),
/// not this repository's concern, the same separation
/// `WbwSelectedPackController` already establishes for word-by-word packs.
///
/// Implemented against Drift by `DriftTranslationRepository`
/// (`lib/quran/data/repositories/drift_translation_repository.dart`),
/// backed by its own database (`lib/quran/data/translation_database.dart`),
/// physically separate from the immutable canonical `QuranDatabase` — see
/// `docs/ARCHITECTURE.md` §4.
abstract class TranslationRepository {
  Future<List<TranslationBook>> getInstalledTranslations();

  Future<TranslationBook?> getInstalledTranslation(String slug);

  /// Installs (or updates in place) [book] with its [verses] — an atomic
  /// replace, checksum-verified before any existing installed data for
  /// [book] is touched. Throws `ResourceChecksumMismatchException`
  /// (`core/downloads/resource_integrity.dart`) if [verses] does not hash to
  /// [TranslationBook.checksum], and `ResourceFormatVersionException` if
  /// [TranslationBook.formatVersion] is not one this build supports —
  /// neither error leaves a previously-installed [book] modified.
  Future<void> installTranslation(
    TranslationBook book,
    List<TranslationVerseText> verses,
  );

  Future<void> deleteTranslation(String slug);

  Future<TranslationVerseText?> getVerseText(
    VerseRef verse, {
    required String slug,
  });

  /// Every verse in [range] for [slug], in a small, fixed number of
  /// queries regardless of range size — the batch counterpart to
  /// [getVerseText], for the reader's per-chapter/Juz/Hizb loading, per
  /// this project's established "do not query once per verse" discipline.
  Future<List<TranslationVerseText>> getVerseRangeText(
    VerseRangeRef range, {
    required String slug,
  });
}
