import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../quran/application/surah_aims_provider.dart';
import '../../../quran/domain/models/ayah_models.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/presentation/surah_name_calligraphy.dart';
import '../../../quran/quran_providers.dart';
import '../../listen/application/quran_audio_player.dart';
import '../application/quran_index_providers.dart';

/// A surah's facts, from the bundled data: its ayahs (juz and sajdahs), its
/// name's meaning where the data has one in the app's language (English).
typedef SurahFacts = ({List<Ayah> ayahs, String? meaning});

final surahFactsProvider = FutureProvider.autoDispose.family<SurahFacts, Surah>(
  (ref, surah) async {
    final repository = ref.watch(quranRepositoryProvider);
    final language = ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final ayahs = await repository.getVerseRange((
      chapterNo: surah.surahNo,
      fromVerseNo: 1,
      toVerseNo: surah.ayahCount,
    ));
    final localization = await repository.getSurahLocalization(
      surah.surahNo,
      languageCode: language,
    );
    return (ayahs: ayahs, meaning: localization?.meaning);
  },
);

/// About surah [surahNo]: its name in the Mushaf's calligraphy, where it
/// was revealed and in which order, its ayahs, rukūʿs, pages, juz and
/// sajdahs, how much of it is memorized, its aims (Al-Mukhtasar's, where
/// it has them in the app's language) — then Read and Listen.
Future<void> showSurahInfoSheet(BuildContext context, {required int surahNo}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      builder: (_) => _SurahInfo(surahNo: surahNo),
    );

class _SurahInfo extends ConsumerWidget {
  const _SurahInfo({required this.surahNo});

  final int surahNo;

  /// "3" or "3–5".
  static String _span(int first, int last) =>
      first == last ? '$first' : '$first–$last';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final indexed = ref
        .watch(indexedSurahsProvider)
        .value
        ?.where((s) => s.surah.surahNo == surahNo)
        .firstOrNull;
    if (indexed == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: TahfeezLoadingView(),
      );
    }
    final surah = indexed.surah;
    final facts = ref.watch(surahFactsProvider(surah)).value;
    final pages = ref.watch(ayahPagesProvider).value;
    final firstPage = pages?[surahNo * 1000 + 1];
    final lastPage = pages?[surahNo * 1000 + surah.ayahCount];
    final ayahs = facts?.ayahs ?? const <Ayah>[];
    final sajdahs = [
      for (final a in ayahs)
        if (a.sajdah != null) a.verseNo,
    ];
    final progress = ref.watch(surahProgressProvider).value?[surahNo];
    // In the app's language only: not another's in its place.
    final language = Localizations.localeOf(context).languageCode;
    final allAims = ref.watch(surahAimsProvider).value;
    final aims = allAims?.of(surahNo, language);
    final translated = allAims?.isTranslated(surahNo, language) ?? false;
    final name = indexed.localizedName ?? indexed.arabicName ?? '$surahNo';

    Widget fact(String label, String value, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.md,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // The values in one column, from the middle: a long one ("6 of 7
          // ayahs memorized") wraps there, not pushed to the far edge.
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return SingleChildScrollView(
      key: ValueKey('surah-info-$surahNo'),
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          Stack(
            children: [
              Column(
                // Full width: the ✕ at the sheet's far end, not the name's.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.xs,
                children: [
                  Center(
                    child: SurahNameCalligraphy(
                      surahNo: surahNo,
                      height: 44,
                      maxWidth: 220,
                      color: theme.colorScheme.onSurface,
                      semanticLabel: indexed.arabicName,
                    ),
                  ),
                  Text(
                    '$surahNo · $name',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (facts?.meaning case final meaning?
                      when meaning.isNotEmpty)
                    Text(
                      meaning,
                      key: const ValueKey('surah-info-meaning'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              PositionedDirectional(
                top: 0,
                end: -TahfeezSpacing.sm,
                child: SheetCloseButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
          TahfeezCard(
            child: Column(
              children: [
                fact(
                  l10n.surahInfoRevelation,
                  surah.revelationType == RevelationType.meccan
                      ? l10n.quranMeccan
                      : l10n.quranMedinan,
                ),
                fact(l10n.surahInfoOrder, '${surah.revelationOrder}'),
                fact(
                  l10n.surahInfoAyahs,
                  '${surah.ayahCount}',
                  key: const ValueKey('surah-info-ayahs'),
                ),
                fact(l10n.surahInfoRukus, '${surah.rukusCount}'),
                if (firstPage != null && lastPage != null)
                  fact(l10n.memUnitPages, _span(firstPage, lastPage)),
                if (ayahs.isNotEmpty)
                  fact(
                    l10n.surahInfoJuz,
                    _span(ayahs.first.juzNo, ayahs.last.juzNo),
                  ),
                if (sajdahs.isNotEmpty)
                  fact(
                    l10n.surahInfoSajdah,
                    sajdahs.map(l10n.surahInfoAyahNo).join(', '),
                    key: const ValueKey('surah-info-sajdah'),
                  ),
                if (progress != null && progress.memorized > 0)
                  fact(
                    l10n.memScoreMemorization,
                    l10n.memPageAyahs(progress.memorized, progress.ayahs),
                    key: const ValueKey('surah-info-memorized'),
                  ),
              ],
            ),
          ),
          if (aims != null)
            TahfeezCard(
              key: const ValueKey('surah-info-aims'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.sm,
                children: [
                  Row(
                    spacing: TahfeezSpacing.sm,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          l10n.surahInfoAims,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    aims,
                    key: const ValueKey('surah-info-aims-text'),
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  Text(
                    translated
                        ? l10n.surahInfoAimsTranslated
                        : l10n.surahInfoAimsSource,
                    key: const ValueKey('surah-info-aims-source'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            spacing: TahfeezSpacing.sm,
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('surah-info-listen'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref
                        .read(quranAudioPlayerProvider.notifier)
                        .playFrom(surahNo * 1000 + 1);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.modeListen),
                ),
              ),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('surah-info-read'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    goToQuranLocation(context, QuranLocation.surah(surahNo));
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.surahInfoRead),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
