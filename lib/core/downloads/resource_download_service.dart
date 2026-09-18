import 'resource_download_status.dart';

/// Interface for enqueuing, tracking, and cancelling downloads of optional
/// resources (translations, tafsir, recitations, word-by-word, atlas
/// bundles, fonts).
///
/// This is an **interface only** for Milestone 1 — per-category versioning
/// (`docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2), background-worker
/// scheduling, and storage integration are built out by the Resource
/// Manager milestone. Defining the contract now lets every earlier
/// milestone that *displays* download state (Home update banners, Settings
/// download screens) code against a stable shape from the start.
abstract class ResourceDownloadService {
  /// Live progress for every resource currently queued/downloading, keyed by
  /// resource id.
  Stream<Map<String, ResourceDownloadProgress>> watchAll();

  Stream<ResourceDownloadProgress> watch(String resourceId);

  Future<void> enqueue(String resourceId);

  Future<void> cancel(String resourceId);

  Future<void> pause(String resourceId);

  Future<void> resume(String resourceId);
}
