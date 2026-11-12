import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/similar_ayahs_provider.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/similar_ayahs.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/reader_mode.dart';
import 'ayah_view_parts.dart';

/// The ayahs [ayahId] is easily mixed up with (mutashābihāt), the most
/// alike first: each in its canonical words, those it does not share with
/// [ayahId] marked — a tap opens it. Nothing at all for an ayah without
/// look-alikes.
class SimilarAyahsSection extends ConsumerStatefulWidget {
  const SimilarAyahsSection({super.key, required this.ayahId});

  final int ayahId;

  /// Shown before "Show all".
  static const firstShown = 3;

  @override
  ConsumerState<SimilarAyahsSection> createState() =>
      _SimilarAyahsSectionState();
}

class _SimilarAyahsSectionState extends ConsumerState<SimilarAyahsSection> {
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final similar = ref.watch(ayahLookAlikesProvider(widget.ayahId));
    if (similar.isEmpty) return const SizedBox.shrink();
    final shown = _all
        ? similar
        : similar.take(SimilarAyahsSection.firstShown).toList();
    return Column(
      key: const ValueKey('similar-ayahs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        TahfeezSectionHeader(
          title: '${l10n.similarAyahsTitle} · ${similar.length}',
          icon: Icons.compare_arrows_rounded,
        ),
        Text(
          l10n.similarAyahsSub,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final s in shown) _SimilarAyahTile(similar: s),
        if (!_all && similar.length > shown.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('similar-ayahs-all'),
              onPressed: () => setState(() => _all = true),
              child: Text(l10n.similarAyahsShowAll(similar.length)),
            ),
          ),
      ],
    );
  }
}

class _SimilarAyahTile extends ConsumerWidget {
  const _SimilarAyahTile({required this.similar});

  final SimilarAyah similar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = similar.ayahId;
    final chapterNo = id ~/ 1000, verseNo = id % 1000;
    final surahName = [
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        if (s.surah.surahNo == chapterNo) s.localizedName ?? s.arabicName,
    ].firstOrNull;
    final words = ref.watch(ayahCanonicalWordsProvider(id)).value;
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    final base = TextStyle(
      fontFamily: font,
      fontSize: 22,
      height: 1.9,
      color: scheme.onSurface,
    );
    return TahfeezCard(
      key: ValueKey('similar-ayah-$id'),
      onTap: () {
        Navigator.of(context).pop();
        goToQuranLocation(context, QuranLocation.ayah(chapterNo, verseNo));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.xs,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  surahName == null
                      ? '$chapterNo:$verseNo'
                      : l10n.homeDailyAyahReferenceNamed(surahName, verseNo),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (similar.identical)
                Flexible(
                  child: Text(
                    l10n.similarAyahsSame,
                    key: ValueKey('similar-ayah-same-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
          if (words != null)
            Text.rich(
              TextSpan(
                children: [
                  for (final (i, w) in words.indexed) ...[
                    if (i > 0) const TextSpan(text: ' '),
                    TextSpan(
                      text: w.text,
                      // The words it does not share: marked.
                      style: similar.differ.contains(w.wordIndex)
                          ? TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              backgroundColor: scheme.primary.withValues(
                                alpha: 0.10,
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
              key: ValueKey('similar-ayah-text-$id'),
              style: base,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
