import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/resource_download_status.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_resource_row.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../application/wbw_library_controller.dart';
import '../application/wbw_preferences_controller.dart';

/// Browse/install/delete WBW language packs — this milestone's "resource
/// states" requirement made concrete, using Tahfeez's own resource-row
/// component (`TahfeezResourceRow`) rather than a bespoke row per this
/// milestone's explicit "do not duplicate the reference settings/resource
/// rows" instruction. Empty (no packs known, installed or otherwise) in the
/// shipped app today — see [WbwLibraryController]'s doc comment for why —
/// but fully real and testable against any installed/cataloged packs.
void showWbwPacksSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Word by word',
    builder: (context) => const _WbwPacksSheetBody(),
  );
}

class _WbwPacksSheetBody extends ConsumerWidget {
  const _WbwPacksSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(wbwLibraryControllerProvider);
    final selectedPackId = ref.watch(wbwSelectedPackControllerProvider);

    return library.when(
      data: (statuses) {
        if (statuses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: TahfeezEmptyView(
              icon: Icons.translate_outlined,
              message: 'No word-by-word language packs available yet.',
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: statuses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final status = statuses[index];
            final isActive = status.pack.id == selectedPackId;
            return TahfeezResourceRow(
              title: isActive
                  ? '${status.pack.displayName} (active)'
                  : status.pack.displayName,
              subtitle: status.pack.languageCode,
              state: _rowState(status.state),
              onAction: () => _onAction(context, ref, status),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => const TahfeezErrorView(
        message: 'Could not load word-by-word language packs.',
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

  void _onAction(BuildContext context, WidgetRef ref, WbwPackStatus status) {
    final controller = ref.read(wbwLibraryControllerProvider.notifier);
    switch (status.state) {
      case ResourceDownloadState.completed:
        ref
            .read(wbwSelectedPackControllerProvider.notifier)
            .select(status.pack.id);
      case ResourceDownloadState.outdated:
      case ResourceDownloadState.notDownloaded:
      case ResourceDownloadState.failed:
        // No real bytes to fetch yet (`WbwPackCatalog` has no concrete
        // network implementation until Milestone 13) — the catalog entry
        // itself carries no word data, so there is nothing to pass
        // `install` today. The action still exercises every reachable
        // resource-state transition once a real catalog exists.
        controller.install(status.pack, const []);
      case ResourceDownloadState.queued:
      case ResourceDownloadState.downloading:
      case ResourceDownloadState.paused:
      case ResourceDownloadState.deleting:
        break;
    }
  }
}
