import '../models/quran_refs.dart';

/// Read/manage access to installed tafsir content.
///
/// See `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5. Full
/// implementation lands with the Translation & Tafsir milestone (9).
abstract class TafsirRepository {
  Future<List<String>> installedTafsirIds();

  Future<String?> activeTafsirId();

  Future<void> setActiveTafsirId(String? tafsirId);

  Future<String?> textFor(VerseRef verse, {required String tafsirId});
}
