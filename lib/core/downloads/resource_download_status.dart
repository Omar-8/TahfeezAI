/// Lifecycle of one downloadable resource item.
///
/// Mirrors the per-resource-category download/version lifecycle confirmed
/// across the reference app (recitations, translations, tafsir, word-by-word,
/// atlas bundles, fonts) in `docs/reference/09_OFFLINE_RESOURCES_SPEC.md`.
enum ResourceDownloadState {
  notDownloaded,
  queued,
  downloading,
  paused,
  completed,
  outdated,
  failed,
  deleting,
}

/// A snapshot of one resource item's download progress, keyed by
/// [resourceId] (an opaque, resource-type-scoped identifier — e.g. a
/// reciter id, a translation slug, a WBW language id).
class ResourceDownloadProgress {
  const ResourceDownloadProgress({
    required this.resourceId,
    required this.state,
    this.receivedBytes = 0,
    this.totalBytes,
  });

  final String resourceId;
  final ResourceDownloadState state;
  final int receivedBytes;

  /// `null` when the server does not report a total size.
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}
