import 'models/translation_models.dart';

/// A source of describable-but-not-yet-installed translations — the
/// "available translations" manifest `docs/reference/09_OFFLINE_RESOURCES_SPEC.md`
/// §2 describes. No concrete network-backed implementation exists yet
/// (Resource Manager, Milestone 13); mirrors `WbwPackCatalog`
/// (`lib/wbw/domain/wbw_pack_catalog.dart`)'s "define the contract now,
/// implement the backend later" shape.
abstract class TranslationCatalog {
  Future<List<TranslationBook>> availableTranslations();
}

/// The production catalog until Milestone 13 exists: honestly reports
/// nothing available, per `docs/CLEAN_ROOM_RULES.md`'s "do not bundle any
/// translation until its redistribution/offline terms are recorded" —
/// no translation's rights have been verified, so none is ever listed.
class NoTranslationCatalog implements TranslationCatalog {
  const NoTranslationCatalog();

  @override
  Future<List<TranslationBook>> availableTranslations() async => const [];
}
