import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/downloads/resource_download_status.dart';
import '../domain/models/tafsir_models.dart';
import '../tafsir_providers.dart';

part 'tafsir_library_controller.g.dart';

/// One tafsir's describable metadata together with its current
/// [ResourceDownloadState] — mirrors `TranslationStatus`
/// (`lib/quran/application/translation_library_controller.dart`) exactly.
typedef TafsirStatus = ({TafsirWork work, ResourceDownloadState state});

/// Merges installed tafsirs ([TafsirRepository]) with cataloged ones
/// ([TafsirCatalog]) into one list of [TafsirStatus]. Mirrors
/// `TranslationLibraryController`'s shape exactly.
@riverpod
class TafsirLibraryController extends _$TafsirLibraryController {
  @override
  Future<List<TafsirStatus>> build() async {
    final repository = ref.watch(tafsirRepositoryProvider);
    final catalog = ref.watch(tafsirCatalogProvider);
    final installed = await repository.getInstalledTafsirs();
    final available = await catalog.availableTafsirs();
    return _merge(installed, available);
  }

  List<TafsirStatus> _merge(
    List<TafsirWork> installed,
    List<TafsirWork> available,
  ) {
    final availableById = {for (final w in available) w.id: w};
    final statuses = <TafsirStatus>[
      for (final work in installed)
        (
          work: work,
          state:
              (availableById[work.id]?.version ?? work.version) > work.version
              ? ResourceDownloadState.outdated
              : ResourceDownloadState.completed,
        ),
      for (final work in available)
        if (!installed.any((w) => w.id == work.id))
          (work: work, state: ResourceDownloadState.notDownloaded),
    ];
    statuses.sort((a, b) => a.work.displayName.compareTo(b.work.displayName));
    return statuses;
  }

  void _setWorkState(String id, ResourceDownloadState newState) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final status in current)
        if (status.work.id == id)
          (work: status.work, state: newState)
        else
          status,
    ]);
  }

  Future<void> install(TafsirWork work, List<TafsirVerseText> verses) async {
    _setWorkState(work.id, ResourceDownloadState.queued);
    _setWorkState(work.id, ResourceDownloadState.downloading);
    try {
      await ref.read(tafsirRepositoryProvider).installTafsir(work, verses);
      final installed = await ref
          .read(tafsirRepositoryProvider)
          .getInstalledTafsirs();
      final available = await ref
          .read(tafsirCatalogProvider)
          .availableTafsirs();
      state = AsyncData(_merge(installed, available));
    } catch (_) {
      _setWorkState(work.id, ResourceDownloadState.failed);
    }
  }

  Future<void> remove(String id) async {
    _setWorkState(id, ResourceDownloadState.deleting);
    await ref.read(tafsirRepositoryProvider).deleteTafsir(id);
    final installed = await ref
        .read(tafsirRepositoryProvider)
        .getInstalledTafsirs();
    final available = await ref.read(tafsirCatalogProvider).availableTafsirs();
    state = AsyncData(_merge(installed, available));
  }
}
