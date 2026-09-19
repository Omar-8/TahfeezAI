import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/surah_models.dart';
import '../../application/reader_session_controller.dart';

/// `ReaderChapterInfoItem`'s card: chapter name/meaning, revelation place,
/// ayah count — `docs/reference/04_READER_SPEC.md` §13's `ChapterInfo`,
/// shown once at the start of a reading session.
class ChapterInfoCard extends ConsumerWidget {
  const ChapterInfoCard({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final localization = ref.watch(
      readerChapterLocalizationProvider(
        surah.surahNo,
        languageCode: languageCode,
      ),
    );
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: TahfeezCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.xs,
          children: [
            Text(
              localization.value?.name ?? 'Surah ${surah.surahNo}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (localization.value?.meaning case final meaning?)
              Text(
                meaning,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: TahfeezSpacing.xs),
            Text(
              '${surah.revelationType == RevelationType.meccan ? 'Meccan' : 'Medinan'} · ${surah.ayahCount} ayahs',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
