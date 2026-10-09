import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/resource_download_status.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../application/translation_library_controller.dart';
import '../application/translation_selection_controller.dart';
import 'meaning_language_names.dart';

/// Which of the bundled translations to show (any number), each with its
/// language — checked ones appear in the ayah sheet and the reader, in the
/// order they were chosen.
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
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(translationLibraryControllerProvider);
    final active = ref.watch(translationSelectionControllerProvider);
    return library.when(
      data: (statuses) {
        final books = [
          for (final s in statuses)
            if (s.state == ResourceDownloadState.completed ||
                s.state == ResourceDownloadState.outdated)
              s.book,
        ];
        if (books.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: TahfeezSpacing.lg),
            child: TahfeezEmptyView(
              icon: Icons.translate_outlined,
              message: l10n.packsNoTranslations,
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.sm,
            0,
            TahfeezSpacing.sm,
            TahfeezSpacing.md,
          ),
          children: [
            for (final book in books)
              CheckboxListTile(
                key: ValueKey('translation-${book.slug}'),
                value: active.contains(book.slug),
                title: Text(book.author),
                subtitle: Text(nativeLanguageName(book.languageCode)),
                onChanged: (_) => ref
                    .read(translationSelectionControllerProvider.notifier)
                    .toggle(book.slug),
              ),
          ],
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => TahfeezErrorView(message: l10n.searchTranslationsError),
    );
  }
}
