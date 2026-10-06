import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../reader/application/quran_display_providers.dart';
import '../../../reader/application/uthmanic_hafs_font_providers.dart';
import '../../application/home_providers.dart';

/// Home's Daily Ayah: today's verse in the Quran script, its first active
/// translation, and a way into the reader at that verse. An honest "not
/// installed yet" state while no Quran dataset is installed.
///
/// The Arabic follows the reader's own rule (`VerseBlock`): the QPC Hafs
/// font only together with its own validated display text for this verse
/// (same word count), otherwise the canonical words through the platform's
/// Arabic font — never the app's UI font, never canonical text forced
/// through the QPC Hafs font.
class HomeDailyAyahSection extends ConsumerWidget {
  const HomeDailyAyahSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dailyAyah = ref.watch(dailyAyahProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionDailyAyah,
          icon: Icons.auto_awesome_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        dailyAyah.when(
          data: (ayah) => ayah == null
              ? TahfeezCard(
                  child: TahfeezEmptyView(
                    icon: Icons.menu_book_outlined,
                    message: l10n.homeQuranDatasetUnavailableBody,
                  ),
                )
              : _DailyAyahCard(ayah: ayah),
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) => TahfeezCard(
            child: TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: l10n.homeQuranDatasetUnavailableBody,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyAyahCard extends ConsumerWidget {
  const _DailyAyahCard({required this.ayah});

  final DailyAyahReference ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fontFamily = ref
        .watch(uthmanicHafsFontManifestProvider)
        .value
        ?.fontFamily;
    final displayWords = ayah.ayahId == null
        ? null
        : ref
              .watch(quranDisplayRepositoryProvider)
              .displayWordsForAyah(ayah.ayahId!);
    final useQpcHafs =
        fontFamily != null &&
        displayWords != null &&
        displayWords.length == ayah.words.length;
    final reference = ayah.chapterName != null
        ? l10n.homeDailyAyahReferenceNamed(ayah.chapterName!, ayah.verseNo)
        : l10n.homeDailyAyahReference(ayah.surahNo, ayah.verseNo);
    void open() => goToQuranLocation(
      context,
      QuranLocation.ayah(ayah.surahNo, ayah.verseNo),
    );

    return TahfeezCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          if (ayah.words.isNotEmpty)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                (useQpcHafs ? displayWords : ayah.words).join(' '),
                textAlign: TextAlign.center,
                style: quranTextStyle(
                  color: scheme.onSurface,
                  fontFamily: useQpcHafs ? fontFamily : null,
                  fontSize: 26,
                ),
              ),
            ),
          if (ayah.translation != null)
            Text(
              ayah.translation!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: open,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(l10n.homeDailyAyahOpen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
