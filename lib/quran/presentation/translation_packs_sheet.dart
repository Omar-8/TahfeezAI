import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/resource_download_status.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_resource_row.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../application/translation_library_controller.dart';
import '../application/translation_selection_controller.dart';

/// Browse/install/delete translations and toggle which installed ones are
/// active in the reader — mirrors `lib/wbw/presentation/wbw_packs_sheet.dart`'s
/// shape, except a "completed" row here toggles membership in a multi-select
/// active list (`TranslationSelectionController`) rather than setting a
/// single selection. Active order is insertion order; drag-to-reorder is a
/// deliberate scope trim (`TranslationSelectionController.reorder` exists
/// and is tested, just not wired to a drag gesture here yet).
void showTranslationPacksSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).searchTranslations,
    builder: (context) => const _TranslationPacksSheetBody(),
  );
}

class _TranslationPacksSheetBody extends ConsumerWidget {
  const _TranslationPacksSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(translationLibraryControllerProvider);
    final activeSlugs = ref.watch(translationSelectionControllerProvider);

    return library.when(
      data: (statuses) {
        if (statuses.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: TahfeezEmptyView(
              icon: Icons.translate_outlined,
              message: AppLocalizations.of(context).packsNoTranslations,
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: statuses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final status = statuses[index];
            final isActive = activeSlugs.contains(status.book.slug);
            return TahfeezResourceRow(
              title: isActive
                  ? AppLocalizations.of(context)
                        .packsActive(status.book.displayName)
                  : status.book.displayName,
              subtitle: status.book.languageCode,
              state: _rowState(status.state),
              onAction: () => _onAction(context, ref, status),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => TahfeezErrorView(
        message: AppLocalizations.of(context).searchTranslationsError,
      ),
    );
  }

  TahfeezResourceRowState _rowState(ResourceDownloadState state) {
    switch (state) {
      case ResourceDownloadState.notDownloaded:
        return TahfeezResourceRowState.notDownloaded;
      case ResourceDownloadState.queued:
        return TahfeezResourceRowState.queued;
      case ResourceDownloadState.downloading:
        return TahfeezResourceRowState.downloading;
      case ResourceDownloadState.paused:
        return TahfeezResourceRowState.downloading;
      case ResourceDownloadState.completed:
        return TahfeezResourceRowState.downloaded;
      case ResourceDownloadState.outdated:
        return TahfeezResourceRowState.outdated;
      case ResourceDownloadState.failed:
        return TahfeezResourceRowState.failed;
      case ResourceDownloadState.deleting:
        return TahfeezResourceRowState.deleting;
    }
  }

  void _onAction(
    BuildContext context,
    WidgetRef ref,
    TranslationStatus status,
  ) {
    final controller = ref.read(translationLibraryControllerProvider.notifier);
    switch (status.state) {
      case ResourceDownloadState.completed:
        ref
            .read(translationSelectionControllerProvider.notifier)
            .toggle(status.book.slug);
      case ResourceDownloadState.outdated:
      case ResourceDownloadState.notDownloaded:
      case ResourceDownloadState.failed:
        // No real bytes to fetch yet — see `TranslationCatalog`'s doc
        // comment.
        controller.install(status.book, const []);
      case ResourceDownloadState.queued:
      case ResourceDownloadState.downloading:
      case ResourceDownloadState.paused:
      case ResourceDownloadState.deleting:
        break;
    }
  }
}
