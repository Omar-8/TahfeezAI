import 'models/tafsir_models.dart';

/// A source of describable-but-not-yet-installed tafsir works — mirrors
/// [TranslationCatalog]'s shape and rationale for tafsir.
abstract class TafsirCatalog {
  Future<List<TafsirWork>> availableTafsirs();
}

/// The production catalog until Milestone 13 exists: honestly reports
/// nothing available, per `docs/CLEAN_ROOM_RULES.md` — no tafsir's rights
/// have been verified, so none is ever listed.
class NoTafsirCatalog implements TafsirCatalog {
  const NoTafsirCatalog();

  @override
  Future<List<TafsirWork>> availableTafsirs() async => const [];
}
