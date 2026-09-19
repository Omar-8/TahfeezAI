import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/downloads/resource_download_status.dart';
import '../domain/models/translation_models.dart';
import '../translation_providers.dart';

part 'translation_library_controller.g.dart';

/// One translation's describable metadata together with its current
/// [ResourceDownloadState] — mirrors `WbwPackStatus`
/// (`lib/wbw/application/wbw_library_controller.dart`) exactly.
typedef TranslationStatus = ({
  TranslationBook book,
  ResourceDownloadState state,
});

/// Merges installed translations ([TranslationRepository]) with cataloged
/// ones ([TranslationCatalog]) into one list of [TranslationStatus], and
/// exposes the install/remove actions a translations browse sheet needs.
/// See `WbwLibraryController`'s doc comment for why [install] writes
/// immediately rather than enqueuing a real background download.
@riverpod
class TranslationLibraryController extends _$TranslationLibraryController {
  @override
  Future<List<TranslationStatus>> build() async {
    final repository = ref.watch(translationRepositoryProvider);
    final catalog = ref.watch(translationCatalogProvider);
    final installed = await repository.getInstalledTranslations();
    final available = await catalog.availableTranslations();
    return _merge(installed, available);
  }

  List<TranslationStatus> _merge(
    List<TranslationBook> installed,
    List<TranslationBook> available,
  ) {
    final availableBySlug = {for (final b in available) b.slug: b};
    final statuses = <TranslationStatus>[
      for (final book in installed)
        (
          book: book,
          state:
              (availableBySlug[book.slug]?.version ?? book.version) >
                  book.version
              ? ResourceDownloadState.outdated
              : ResourceDownloadState.completed,
        ),
      for (final book in available)
        if (!installed.any((b) => b.slug == book.slug))
          (book: book, state: ResourceDownloadState.notDownloaded),
    ];
    statuses.sort((a, b) => a.book.displayName.compareTo(b.book.displayName));
    return statuses;
  }

  void _setBookState(String slug, ResourceDownloadState newState) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final status in current)
        if (status.book.slug == slug)
          (book: status.book, state: newState)
        else
          status,
    ]);
  }

  Future<void> install(
    TranslationBook book,
    List<TranslationVerseText> verses,
  ) async {
    _setBookState(book.slug, ResourceDownloadState.queued);
    _setBookState(book.slug, ResourceDownloadState.downloading);
    try {
      await ref
          .read(translationRepositoryProvider)
          .installTranslation(book, verses);
      final installed = await ref
          .read(translationRepositoryProvider)
          .getInstalledTranslations();
      final available = await ref
          .read(translationCatalogProvider)
          .availableTranslations();
      state = AsyncData(_merge(installed, available));
    } catch (_) {
      _setBookState(book.slug, ResourceDownloadState.failed);
    }
  }

  Future<void> remove(String slug) async {
    _setBookState(slug, ResourceDownloadState.deleting);
    await ref.read(translationRepositoryProvider).deleteTranslation(slug);
    final installed = await ref
        .read(translationRepositoryProvider)
        .getInstalledTranslations();
    final available = await ref
        .read(translationCatalogProvider)
        .availableTranslations();
    state = AsyncData(_merge(installed, available));
  }
}
