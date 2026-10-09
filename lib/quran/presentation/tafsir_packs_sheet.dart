import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/resource_download_status.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../application/tafsir_library_controller.dart';
import '../application/tafsir_selection_controller.dart';
import 'meaning_language_names.dart';

/// Which bundled tafsir to show (one, or none), each with its language.
void showTafsirPacksSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).readerTafsir,
    builder: (context) => const _TafsirPacksSheetBody(),
  );
}

class _TafsirPacksSheetBody extends ConsumerWidget {
  const _TafsirPacksSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(tafsirLibraryControllerProvider);
    final active = ref.watch(tafsirSelectionControllerProvider);
    void select(String? id) =>
        ref.read(tafsirSelectionControllerProvider.notifier).select(id);
    return library.when(
      data: (statuses) {
        final works = [
          for (final s in statuses)
            if (s.state == ResourceDownloadState.completed ||
                s.state == ResourceDownloadState.outdated)
              s.work,
        ];
        if (works.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: TahfeezSpacing.lg),
            child: TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: l10n.packsNoTafsir,
            ),
          );
        }
        return RadioGroup<String>(
          groupValue: active ?? '',
          onChanged: (id) => select(id == null || id.isEmpty ? null : id),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TahfeezSpacing.sm,
              0,
              TahfeezSpacing.sm,
              TahfeezSpacing.md,
            ),
            children: [
              for (final work in works)
                RadioListTile<String>(
                  key: ValueKey('tafsir-${work.id}'),
                  value: work.id,
                  title: Text(work.displayName),
                  subtitle: Text(nativeLanguageName(work.languageCode)),
                ),
              RadioListTile<String>(
                key: const ValueKey('tafsir-none'),
                value: '',
                title: Text(l10n.settingsTafsirNone),
              ),
            ],
          ),
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => TahfeezErrorView(message: l10n.packsTafsirError),
    );
  }
}
