import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../application/home_providers.dart';

/// Home's Daily Ayah: today's verse in the Quran script, its first active
/// translation, and a way into the reader at that verse. An honest "not
/// installed yet" state while no Quran dataset is installed.
///
/// The Arabic is the verse's canonical words, unchanged, in Scheherazade
/// New — a font designed for Quran text (`docs/THIRD_PARTY_RESOURCES.md`)
/// — never the app's UI font.
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

/// Amiri Quran: a Quran font (`docs/THIRD_PARTY_RESOURCES.md`) in the
/// classical calligraphic naskh — the daily ayah shown as a calligraphy
/// piece.
const _dailyAyahFont = 'Amiri Quran';

/// Arabic-Indic digits for the ayah's number in its marker.
String _arabicDigits(int n) =>
    '$n'.split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

class _DailyAyahCard extends ConsumerWidget {
  const _DailyAyahCard({required this.ayah});

  final DailyAyahReference ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reference = ayah.chapterName != null
        ? l10n.homeDailyAyahReferenceNamed(ayah.chapterName!, ayah.verseNo)
        : l10n.homeDailyAyahReference(ayah.surahNo, ayah.verseNo);
    void open() => goToQuranLocation(
      context,
      QuranLocation.ayah(ayah.surahNo, ayah.verseNo),
    );
    // Larger on wider screens.
    final arabicSize = MediaQuery.sizeOf(context).width >= 600 ? 38.0 : 32.0;

    return TahfeezCard(
      onTap: open,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: TahfeezGeometricPattern(
              color: scheme.tertiary.withValues(alpha: 0.07),
              spacing: 40,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TahfeezSpacing.md,
              TahfeezSpacing.md,
              TahfeezSpacing.md,
              TahfeezSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.smPlus,
              children: [
                _Ornament(color: scheme.tertiary),
                if (ayah.words.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: ayah.words.join(' ')),
                          const TextSpan(text: ' '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            // Its number in a drawn star, not a font glyph.
                            child: TahfeezStarNumber(
                              label: _arabicDigits(ayah.verseNo),
                              color: scheme.tertiary,
                              size: arabicSize * 0.95,
                              textStyle: const TextStyle(
                                fontFamily: 'Noto Naskh Arabic',
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: quranTextStyle(
                        color: scheme.onSurface,
                        fontFamily: _dailyAyahFont,
                        fontSize: arabicSize,
                      ).copyWith(height: 2.0),
                    ),
                  ),
                if (ayah.translation != null)
                  Text(
                    ayah.translation!,
                    // Its own language's direction, whatever the app's (an
                    // English translation in the Arabic app, an Urdu one in
                    // the English app).
                    textDirection:
                        const {
                          'ar',
                          'ur',
                          'fa',
                          'ckb',
                          'ps',
                        }.contains(ayah.translationLanguage)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
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
                    // Sharing the row: a long name at large text shortened,
                    // not pushed off.
                    Flexible(
                      child: TextButton.icon(
                        onPressed: open,
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(
                          l10n.homeDailyAyahOpen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Above the ayah: the eight-pointed star between two fading lines.
class _Ornament extends StatelessWidget {
  const _Ornament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line(bool towardsStar) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: towardsStar ? 0 : 0.5),
              color.withValues(alpha: towardsStar ? 0.5 : 0),
            ],
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        spacing: TahfeezSpacing.sm,
        children: [
          line(true),
          TahfeezStar(color: color, size: 16),
          line(false),
        ],
      ),
    );
  }
}
