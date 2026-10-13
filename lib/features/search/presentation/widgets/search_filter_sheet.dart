import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/downloads/resource_download_status.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/application/translation_library_controller.dart';
import '../../application/search_filters_controller.dart';
import '../../../../quran/application/translation_selection_controller.dart';
import '../../../../quran/presentation/meaning_resource_names.dart';

/// Which search domains/translations a query runs against
/// (`docs/reference/07_SEARCH_SPEC.md` §5's `SearchFilterSheet`) —
/// independently designed, using Tahfeez's own bottom-sheet/switch/chip
/// components rather than a copy of the reference screen.
void showSearchFilterSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).searchFilters,
    builder: (context) => const _SearchFilterSheetBody(),
  );
}

class _SearchFilterSheetBody extends ConsumerWidget {
  const _SearchFilterSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersControllerProvider);
    final controller = ref.read(searchFiltersControllerProvider.notifier);
    final installedTranslations = ref.watch(
      translationLibraryControllerProvider,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.of(context).searchArabicText),
            value: filters.includeArabicText,
            onChanged: (value) =>
                controller.update(filters.copyWith(includeArabicText: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.of(context).searchSurahNames),
            value: filters.includeSurahs,
            onChanged: (value) =>
                controller.update(filters.copyWith(includeSurahs: value)),
          ),
          const SizedBox(height: TahfeezSpacing.sm),
          Text(
            AppLocalizations.of(context).searchTranslations,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: TahfeezSpacing.xs),
          installedTranslations.when(
            data: (statuses) {
              final settingsSlugs = ref
                  .watch(translationSelectionControllerProvider)
                  .toSet();
              final installedSlugs = [
                for (final status in statuses)
                  if (status.state == ResourceDownloadState.completed ||
                      status.state == ResourceDownloadState.outdated)
                    status.book.slug,
              ];
              if (installedSlugs.isEmpty) {
                return Text(AppLocalizations.of(context).searchNoTranslations);
              }
              return Wrap(
                spacing: TahfeezSpacing.xs,
                runSpacing: TahfeezSpacing.xs,
                children: [
                  for (final status in statuses)
                    if (installedSlugs.contains(status.book.slug))
                      TahfeezFilterChip(
                        label: translationNameWithLanguage(
                          AppLocalizations.of(context),
                          status.book,
                        ),
                        // No choice made here: the Settings' translations.
                        selected: (filters.translationSlugs ?? settingsSlugs)
                            .contains(status.book.slug),
                        onSelected: (selected) {
                          final current =
                              filters.translationSlugs?.toSet() ??
                              settingsSlugs.toSet();
                          final updated = selected
                              ? (current..add(status.book.slug))
                              : (current..remove(status.book.slug));
                          controller.update(
                            filters.copyWith(translationSlugs: updated),
                          );
                        },
                      ),
                ],
              );
            },
            loading: () => const TahfeezLoadingView(),
            error: (_, _) =>
                Text(AppLocalizations.of(context).searchTranslationsError),
          ),
        ],
      ),
    );
  }
}
