import 'models/wbw_models.dart';

/// A source of describable-but-not-yet-installed WBW packs — the "available
/// WBW language packs" manifest `docs/reference/09_OFFLINE_RESOURCES_SPEC.md`
/// §2 describes (`available_wbw_info_v2.json` in the reference app).
///
/// No concrete network-backed implementation exists yet; fetching a real
/// manifest and the resource-download infrastructure to actually retrieve a
/// pack's bytes are the Resource Manager milestone's job (13), per
/// `docs/ARCHITECTURE.md` §9. This interface exists now so the WBW library
/// UI can already distinguish "installed," "installed but outdated," and
/// "known but not installed" states against a real (if empty) source, the
/// same "define the contract now, implement the backend later" pattern
/// `ResourceDownloadService`/`ResourceRepository` (`core/downloads/`) already
/// established in Milestone 1.
abstract class WbwPackCatalog {
  Future<List<WbwLanguagePack>> availablePacks();
}

/// The production catalog until Milestone 13 exists: honestly reports
/// nothing available, rather than fabricating a fake manifest — the same
/// "no real dataset shipped yet" pattern `hasInstalledQuranDatasetProvider`
/// (`lib/quran/application/quran_dataset_status.dart`) already established
/// for the canonical Quran dataset itself.
class NoWbwPackCatalog implements WbwPackCatalog {
  const NoWbwPackCatalog();

  @override
  Future<List<WbwLanguagePack>> availablePacks() async => const [];
}
