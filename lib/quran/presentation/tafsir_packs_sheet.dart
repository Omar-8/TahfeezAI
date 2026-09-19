import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/resource_download_status.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_resource_row.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../application/tafsir_library_controller.dart';
import '../application/tafsir_selection_controller.dart';

/// Browse/install/delete tafsir works and pick the single active one —
/// mirrors `lib/wbw/presentation/wbw_packs_sheet.dart`'s shape exactly,
/// except selecting a row here also sets it as the single active tafsir
/// (tafsir is single-select, unlike WBW packs and translations).
void showTafsirPacksSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Tafsir library',
    builder: (context) => const _TafsirPacksSheetBody(),
  );
}

class _TafsirPacksSheetBody extends ConsumerWidget {
  const _TafsirPacksSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(tafsirLibraryControllerProvider);
    final activeTafsirId = ref.watch(tafsirSelectionControllerProvider);

    return library.when(
      data: (statuses) {
        if (statuses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: 'No tafsir works available yet.',
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: statuses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final status = statuses[index];
            final isActive = status.work.id == activeTafsirId;
            return TahfeezResourceRow(
              title: isActive
                  ? '${status.work.displayName} (active)'
                  : status.work.displayName,
              subtitle: status.work.languageCode,
              state: _rowState(status.state),
              onAction: () => _onAction(context, ref, status),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) =>
          const TahfeezErrorView(message: 'Could not load tafsir works.'),
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

  void _onAction(BuildContext context, WidgetRef ref, TafsirStatus status) {
    final controller = ref.read(tafsirLibraryControllerProvider.notifier);
    switch (status.state) {
      case ResourceDownloadState.completed:
        ref
            .read(tafsirSelectionControllerProvider.notifier)
            .select(status.work.id);
      case ResourceDownloadState.outdated:
      case ResourceDownloadState.notDownloaded:
      case ResourceDownloadState.failed:
        // No real bytes to fetch yet — see `TafsirCatalog`'s doc comment.
        controller.install(status.work, const []);
      case ResourceDownloadState.queued:
      case ResourceDownloadState.downloading:
      case ResourceDownloadState.paused:
      case ResourceDownloadState.deleting:
        break;
    }
  }
}
