import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/reader_session_controller.dart';

/// `ReaderChapterTitleItem`'s header: a chapter-name divider used when a
/// reading session spans multiple chapters (Juz/Hizb reading, or
/// continuous scrolling into the next chapter) to mark a chapter boundary
/// inline — `docs/reference/04_READER_SPEC.md` §13's `ChapterTitle`.
class ChapterTitleHeader extends ConsumerWidget {
  const ChapterTitleHeader({super.key, required this.surahNo});

  final int surahNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final localization = ref.watch(
      readerChapterLocalizationProvider(surahNo, languageCode: languageCode),
    );
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.md,
        vertical: TahfeezSpacing.sm,
      ),
      child: Text(
        localization.value?.name ?? 'Surah $surahNo',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
