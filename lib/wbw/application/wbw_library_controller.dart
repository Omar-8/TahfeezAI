import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/downloads/resource_download_status.dart';
import '../domain/models/wbw_models.dart';
import '../wbw_providers.dart';

part 'wbw_library_controller.g.dart';

/// One WBW pack's describable metadata together with its current
/// [ResourceDownloadState] — the shape a WBW packs sheet renders one
/// `TahfeezResourceRow` from. Deliberately the pure, presentation-independent
/// [ResourceDownloadState] (`core/downloads/resource_download_status.dart`),
/// not the presentation-only `TahfeezResourceRowState`
/// (`core/theme/components/tahfeez_resource_row.dart`) — mapping between the
/// two is the presentation widget's job, per that enum's own doc comment.
typedef WbwPackStatus = ({WbwLanguagePack pack, ResourceDownloadState state});

/// Merges what is locally installed ([WbwRepository]) with what is known to
/// be available ([WbwPackCatalog]) into one list of [WbwPackStatus], and
/// exposes the install/remove actions a WBW packs sheet needs.
///
/// No real network download exists yet (Milestone 13 — see
/// [WbwPackCatalog]'s doc comment), so [install] performs the actual write
/// (`WbwRepository.installPack`) immediately rather than enqueuing a
/// background download; it still transitions through
/// [ResourceDownloadState.queued]/[ResourceDownloadState.downloading] first
/// so every state this milestone's Definition of Done requires is real and
/// observable, not skipped just because the write itself is fast today.
@riverpod
class WbwLibraryController extends _$WbwLibraryController {
  @override
  Future<List<WbwPackStatus>> build() async {
    final repository = ref.watch(wbwRepositoryProvider);
    final catalog = ref.watch(wbwPackCatalogProvider);
    final installed = await repository.getInstalledPacks();
    final available = await catalog.availablePacks();
    return _merge(installed, available);
  }

  List<WbwPackStatus> _merge(
    List<WbwLanguagePack> installed,
    List<WbwLanguagePack> available,
  ) {
    final availableById = {for (final p in available) p.id: p};
    final statuses = <WbwPackStatus>[
      for (final pack in installed)
        (
          pack: pack,
          state:
              (availableById[pack.id]?.version ?? pack.version) > pack.version
              ? ResourceDownloadState.outdated
              : ResourceDownloadState.completed,
        ),
      for (final pack in available)
        if (!installed.any((p) => p.id == pack.id))
          (pack: pack, state: ResourceDownloadState.notDownloaded),
    ];
    statuses.sort((a, b) => a.pack.displayName.compareTo(b.pack.displayName));
    return statuses;
  }

  void _setPackState(String packId, ResourceDownloadState newState) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final status in current)
        if (status.pack.id == packId)
          (pack: status.pack, state: newState)
        else
          status,
    ]);
  }

  /// Installs (or updates) [pack] with its [words] — see the class doc
  /// comment for why this is a real, immediate local write rather than a
  /// queued background download.
  Future<void> install(WbwLanguagePack pack, List<WbwWordEntry> words) async {
    _setPackState(pack.id, ResourceDownloadState.queued);
    _setPackState(pack.id, ResourceDownloadState.downloading);
    try {
      await ref.read(wbwRepositoryProvider).installPack(pack, words);
      final installed = await ref
          .read(wbwRepositoryProvider)
          .getInstalledPacks();
      final available = await ref.read(wbwPackCatalogProvider).availablePacks();
      state = AsyncData(_merge(installed, available));
    } catch (_) {
      _setPackState(pack.id, ResourceDownloadState.failed);
    }
  }

  Future<void> remove(String packId) async {
    _setPackState(packId, ResourceDownloadState.deleting);
    await ref.read(wbwRepositoryProvider).deletePack(packId);
    final installed = await ref.read(wbwRepositoryProvider).getInstalledPacks();
    final available = await ref.read(wbwPackCatalogProvider).availablePacks();
    state = AsyncData(_merge(installed, available));
  }
}
