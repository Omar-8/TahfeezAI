import '../resource_download_status.dart';

/// Domain-first read model for "what optional resources exist and what
/// state are they in", independent of how they are fetched or stored.
///
/// Concrete implementations (composing [ResourceDownloadService] with local
/// version-tracking storage, per `docs/reference/09_OFFLINE_RESOURCES_SPEC.md`
/// §2) arrive with the Resource Manager milestone.
abstract class ResourceRepository {
  Stream<ResourceDownloadState> watchState(String resourceId);

  Future<bool> isInstalled(String resourceId);

  /// Resource ids installed locally but older than the latest known remote
  /// version — the set the Home "resource updates available" banner and
  /// Settings download screens read from
  /// (`docs/reference/11_HOME_SPEC.md` §2, `docs/reference/10_SETTINGS_SPEC.md`).
  Stream<Set<String>> watchOutdatedResourceIds();
}
