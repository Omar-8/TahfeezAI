import '../models/quran_refs.dart';

/// Read/manage access to installed Quran translations.
///
/// Per `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`, more than one
/// translation may be simultaneously active; installing/removing a
/// translation is independent of selecting it for display. Full
/// implementation lands with the Translation & Tafsir milestone (9).
abstract class TranslationRepository {
  Future<List<String>> installedTranslationSlugs();

  Future<List<String>> activeTranslationSlugs();

  Future<void> setActiveTranslationSlugs(List<String> slugs);

  Future<String?> textFor(VerseRef verse, {required String translationSlug});
}
