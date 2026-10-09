import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_progress.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_models.dart';
import '../../../memorization/domain/progress_map.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../quran/application/quran_index_providers.dart';
import 'mark_known_sheet.dart';
import 'memorize_screen.dart';

/// Memorization progress (`docs/MEMORIZATION_MILESTONE.md`, M4): how much of
/// the Quran is memorized, a strength map of every page juz by juz, and the
/// weakest pages to revise — with marking what is already known.
class MemorizationProgressScreen extends ConsumerWidget {
  const MemorizationProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final map = ref.watch(progressMapProvider);
    // The label where there is room for it beside the title (the back button,
    // the icon and the padding take about 140 dp).
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    double width(String text, TextStyle? style) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout()).width;
    final labelFits =
        width(l10n.memMarkKnown, theme.textTheme.labelLarge) +
            width(l10n.memProgressTitle, theme.textTheme.titleLarge) +
            140 <=
        MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: TahfeezAppBar(
        title: Text(l10n.memProgressTitle),
        centerTitle: false,
        actions: [
          if (labelFits)
            TextButton.icon(
              key: const ValueKey('mem-mark-known'),
              onPressed: () => showMarkKnownSheet(context),
              icon: const Icon(Icons.playlist_add_check),
              label: Text(l10n.memMarkKnown),
            )
          else
            IconButton(
              key: const ValueKey('mem-mark-known'),
              tooltip: l10n.memMarkKnown,
              onPressed: () => showMarkKnownSheet(context),
              icon: const Icon(Icons.playlist_add_check),
            ),
        ],
      ),
      body: map.when(
        loading: () => const TahfeezLoadingView(),
        error: (e, _) => TahfeezEmptyView(message: '$e'),
        data: (map) => ListView(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          children: [
            _Summary(map: map),
            const SizedBox(height: TahfeezSpacing.lg),
            TahfeezSectionHeader(
              title: l10n.memMapTitle,
              icon: Icons.grid_view_outlined,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            _StrengthMap(map: map),
            const SizedBox(height: TahfeezSpacing.lg),
            TahfeezSectionHeader(
              title: l10n.memWeakTitle,
              icon: Icons.trending_down,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            _WeakPages(map: map),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.map});

  final ProgressMap map;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return TahfeezCard(
      key: const ValueKey('mem-progress-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Text(
            l10n.memProgressShare((map.share * 100).round()),
            style: theme.textTheme.titleMedium,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(TahfeezRadii.pill),
            child: LinearProgressIndicator(
              value: map.share,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            l10n.memPlanProgress(map.memorized, map.ayahs),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (map.strength != null)
            ScoreBar(label: l10n.memStrengthLabel, value: map.strength!),
          if (map.unverified > 0)
            Text(
              l10n.memProgressUnverified(map.unverified),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A page's square: empty when nothing on it is memorized, outlined when
/// only marked (not recited yet), else its strength's colour — paler the
/// less of the page is memorized.
Color? _cellColor(PageProgress p, ColorScheme scheme) {
  if (p.isEmpty) return scheme.surfaceContainerHighest;
  final s = p.strength;
  if (s == null) return null;
  final share = p.memorized / p.ayahs;
  return ScoreBar.colorOf(s, scheme).withValues(alpha: 0.35 + 0.65 * share);
}

class _StrengthMap extends StatelessWidget {
  const _StrengthMap({required this.map});

  final ProgressMap map;

  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget legend(Color? fill, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TahfeezSpacing.xs,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            border: fill == null ? Border.all(color: scheme.primary) : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Flexible(child: Text(label, style: theme.textTheme.labelSmall)),
      ],
    );

    return TahfeezCard(
      key: const ValueKey('mem-strength-map'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _gap,
        children: [
          for (final juz in map.juz)
            Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${juz.juz}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final n = juz.pages.length;
                      final cell = ((box.maxWidth - (n - 1) * _gap) / n).clamp(
                        4.0,
                        16.0,
                      );
                      return Row(
                        spacing: _gap,
                        children: [
                          for (final p in juz.pages)
                            _PageCell(page: p, size: cell),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: TahfeezSpacing.sm),
          Wrap(
            spacing: TahfeezSpacing.md,
            runSpacing: TahfeezSpacing.xs,
            children: [
              legend(scheme.primary, l10n.memMapStrong),
              legend(scheme.tertiary, l10n.memMapFading),
              legend(scheme.error, l10n.memMapWeak),
              legend(null, l10n.memUnverified),
              legend(scheme.surfaceContainerHighest, l10n.memMapNone),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageCell extends ConsumerWidget {
  const _PageCell({required this.page, required this.size});

  final PageProgress page;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fill = _cellColor(page, scheme);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).memPage(page.page),
      child: GestureDetector(
        key: ValueKey('mem-map-page-${page.page}'),
        onTap: () => _showPage(context, ref, page),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            border: fill == null
                ? Border.all(color: scheme.primary, width: 1.2)
                : null,
            borderRadius: BorderRadius.circular(size / 5),
          ),
        ),
      ),
    );
  }
}

/// A page from the map: how much of it is memorized and how strongly, with
/// a way to open it or revise it. The actions use [ref] (the map's), which
/// outlives the sheet.
void _showPage(BuildContext context, WidgetRef ref, PageProgress page) {
  final l10n = AppLocalizations.of(context);
  showTahfeezModalBottomSheet<void>(
    context: context,
    title: '${l10n.memPage(page.page)} · ${l10n.memJuzNo(page.juz)}',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, sheetRef, _) {
        final theme = Theme.of(sheetContext);
        final memories =
            sheetRef.watch(ayahMemoriesProvider).value ??
            const <int, AyahMemory>{};
        final memorized = page.memorizedIn(memories);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            0,
            TahfeezSpacing.md,
            TahfeezSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.smPlus,
            children: [
              Text(
                l10n.memPageAyahs(page.memorized, page.ayahs),
                style: theme.textTheme.bodyMedium,
              ),
              if (page.strength != null)
                ScoreBar(label: l10n.memStrengthLabel, value: page.strength!),
              if (page.unverified > 0)
                Text(
                  l10n.memProgressUnverified(page.unverified),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Row(
                spacing: TahfeezSpacing.sm,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final mushaf = await ref.read(
                          defaultMushafProvider.future,
                        );
                        if (mushaf == null || !context.mounted) return;
                        Navigator.of(sheetContext).pop();
                        goToQuranLocation(
                          context,
                          QuranLocation.page(mushaf.id, page.page),
                        );
                      },
                      child: Text(l10n.memOpenPage),
                    ),
                  ),
                  if (memorized.isNotEmpty)
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          reciteAyahs(
                            context,
                            ref,
                            memorized.first,
                            memorized.last,
                            page: page.page,
                          );
                        },
                        child: Text(l10n.memRevise),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _WeakPages extends ConsumerWidget {
  const _WeakPages({required this.map});

  final ProgressMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (map.weak.isEmpty) {
      return TahfeezCard(child: Text(l10n.memWeakNone));
    }
    final names = surahNames(ref);
    final memories =
        ref.watch(ayahMemoriesProvider).value ?? const <int, AyahMemory>{};
    return TahfeezCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, p) in map.weak.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Builder(
              builder: (context) {
                final ayahs = p.memorizedIn(memories);
                if (ayahs.isEmpty) return const SizedBox.shrink();
                return Padding(
                  key: ValueKey('mem-weak-page-${p.page}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: TahfeezSpacing.md,
                    vertical: TahfeezSpacing.smPlus,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: TahfeezSpacing.sm,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ayahRangeLabel(
                                    ayahs.first,
                                    ayahs.last,
                                    names,
                                  ),
                                  style: theme.textTheme.bodyLarge,
                                ),
                                Text(
                                  l10n.memPage(p.page),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => reciteAyahs(
                              context,
                              ref,
                              ayahs.first,
                              ayahs.last,
                              page: p.page,
                            ),
                            child: Text(l10n.memStart),
                          ),
                        ],
                      ),
                      ScoreBar(
                        label: l10n.memStrengthLabel,
                        value: p.strength!,
                        dense: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
