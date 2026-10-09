import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../../quran/domain/models/surah_models.dart';
import '../../../../memorization/application/memorization_today.dart';
import '../../../memorize/presentation/memorize_screen.dart' show ScoreBar;
import '../../application/quran_index_providers.dart';

enum _RevelationFilter { all, meccan, medinan }

/// The search bar's and filter button's shared height — a single constant
/// so the two can never drift apart by sizing independently to their own
/// content (the search `TextField`'s natural height vs. an `IconButton`'s
/// default Material tap target are not the same by default).
const _searchBarHeight = 44.0;

/// The Surah navigator tab: every chapter, searchable by number/name and
/// filterable by revelation place — `docs/reference/02_SCREEN_INVENTORY.md`
/// §5's "Chapters" tab reimagined with Tahfeez's own components rather than
/// its exact filter set (no length/Sajdah filter here; see this milestone's
/// scope notes in `docs/ARCHITECTURE.md`).
class SurahIndexTab extends ConsumerStatefulWidget {
  const SurahIndexTab({super.key, required this.onSelect});

  final ValueChanged<QuranLocation> onSelect;

  @override
  ConsumerState<SurahIndexTab> createState() => _SurahIndexTabState();
}

class _SurahIndexTabState extends ConsumerState<SurahIndexTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _RevelationFilter _filter = _RevelationFilter.all;
  bool _reversed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<IndexedSurah> _apply(List<IndexedSurah> all) {
    final query = _query.trim().toLowerCase();
    final matched = [
      for (final indexed in all)
        if (_matchesFilter(indexed.surah) && _matchesQuery(indexed, query))
          indexed,
    ];
    return _reversed ? matched.reversed.toList() : matched;
  }

  bool _matchesFilter(Surah surah) {
    return switch (_filter) {
      _RevelationFilter.all => true,
      _RevelationFilter.meccan => surah.revelationType == RevelationType.meccan,
      _RevelationFilter.medinan =>
        surah.revelationType == RevelationType.medinan,
    };
  }

  bool _matchesQuery(IndexedSurah indexed, String query) {
    if (query.isEmpty) return true;
    if (indexed.surah.surahNo.toString() == query) return true;
    final name = indexed.localizedName?.toLowerCase() ?? '';
    final arabicName = indexed.arabicName?.toLowerCase() ?? '';
    return name.contains(query) || arabicName.contains(query);
  }

  void _showFilterSheet() {
    // Counts are of every Surah (never just the currently-searched/filtered
    // subset) -- this sheet is the "change the filter" surface, so it should
    // always answer "how many Meccan/Medinan chapters are there in total,"
    // not "how many currently match my search." "All" gets no count: its
    // meaning (114, the whole Mushaf) is self-evident and would just repeat
    // the other two chips' sum right next to them.
    final all = ref.read(indexedSurahsProvider).value ?? const [];
    final meccanCount = all
        .where((s) => s.surah.revelationType == RevelationType.meccan)
        .length;
    final medinanCount = all
        .where((s) => s.surah.revelationType == RevelationType.medinan)
        .length;

    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).quranFilterChapters,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void select(_RevelationFilter value) {
            setState(() => _filter = value);
            setSheetState(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Wrap(
              spacing: TahfeezSpacing.sm,
              children: [
                TahfeezFilterChip(
                  label: AppLocalizations.of(context).quranFilterAll,
                  selected: _filter == _RevelationFilter.all,
                  onSelected: (_) => select(_RevelationFilter.all),
                ),
                TahfeezFilterChip(
                  label: AppLocalizations.of(context)
                      .quranMeccanCount(meccanCount),
                  selected: _filter == _RevelationFilter.meccan,
                  onSelected: (_) => select(_RevelationFilter.meccan),
                ),
                TahfeezFilterChip(
                  label: AppLocalizations.of(context)
                      .quranMedinanCount(medinanCount),
                  selected: _filter == _RevelationFilter.medinan,
                  onSelected: (_) => select(_RevelationFilter.medinan),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(indexedSurahsProvider);
    final scheme = Theme.of(context).colorScheme;
    // Memorization and tajweed, for the surahs worked on.
    final progress = ref.watch(surahProgressProvider).value ?? const {};

    return Column(
      children: [
        Padding(
          // A little more top margin than a typical section
          // (`TahfeezSpacing.smPlus`, not `.sm`): this tab's content sits
          // directly under the Quran index's `TabBar`
          // (`quran_index_screen.dart`), which otherwise reads as cramped
          // against the search bar right below it -- but not so much that
          // it pushes the search bar noticeably far from the tabs above it.
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            TahfeezSpacing.smPlus,
            TahfeezSpacing.md,
            TahfeezSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // A filled, borderless pill -- not a plain underlined/outlined
              // `TextField` -- matching a modern search bar's usual shape
              // rather than a generic form-field look. Fixed to
              // `_searchBarHeight` so it lines up exactly with the filter
              // button beside it, rather than each sizing independently to
              // its own content and drifting apart by a few pixels.
              Expanded(
                child: SizedBox(
                  height: _searchBarHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      // Without this, the hint text/input baseline sits
                      // slightly above true center within the search bar's
                      // now-fixed `_searchBarHeight` box (`TextField`'s
                      // default vertical alignment accounts for its own
                      // natural content height, not an ancestor-imposed
                      // fixed height) -- while the prefix search icon,
                      // constrained separately, already looked centered.
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                            .quranSearchChapters,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: TahfeezSpacing.sm,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: scheme.onSurfaceVariant,
                                ),
                                tooltip: AppLocalizations.of(context)
                                    .quranClear,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TahfeezSpacing.sm),
              // Beside the search bar, not stacked under it -- opens a
              // sheet with the same Meccan/Medinan/All choice the tab used
              // to show as a permanent chip row, so the space that row
              // took is given back to the chapter list. Same fixed height
              // and tight `constraints`/`padding` so the button itself
              // (not just its `DecoratedBox`) actually fills that height,
              // rather than centering a smaller Material tap target inside it.
              SizedBox(
                height: _searchBarHeight,
                width: _searchBarHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  ),
                  child: IconButton(
                    onPressed: _showFilterSheet,
                    tooltip: AppLocalizations.of(context).quranFilterChapters,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: _searchBarHeight,
                      height: _searchBarHeight,
                    ),
                    icon: Badge(
                      isLabelVisible: _filter != _RevelationFilter.all,
                      smallSize: 8,
                      child: Icon(
                        Icons.filter_list,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TahfeezSpacing.sm),
              // Reverses the (filtered/searched) list to start from the
              // last chapter -- same fixed-size treatment as the filter
              // button beside it, so all three controls share one row and
              // one height.
              SizedBox(
                height: _searchBarHeight,
                width: _searchBarHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _reversed
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  ),
                  child: IconButton(
                    onPressed: () => setState(() => _reversed = !_reversed),
                    tooltip: _reversed
                        ? AppLocalizations.of(context).quranShowingLastFirst
                        : AppLocalizations.of(context).quranShowLastFirst,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: _searchBarHeight,
                      height: _searchBarHeight,
                    ),
                    icon: Icon(
                      Icons.swap_vert,
                      color: _reversed
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: surahs.when(
            data: (all) {
              final filtered = _apply(all);
              if (all.isEmpty) {
                return TahfeezEmptyView(
                  icon: Icons.menu_book_outlined,
                  message: AppLocalizations.of(context)
                      .homeQuranDatasetUnavailableBody,
                );
              }
              if (filtered.isEmpty) {
                return TahfeezEmptyView(
                  icon: Icons.search_off,
                  message: AppLocalizations.of(context).quranNoChaptersMatch,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: TahfeezSpacing.md,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final indexed = filtered[index];
                  final subtitleParts = [
                    AppLocalizations.of(context)
                        .homeFeaturedAyahCount(indexed.surah.ayahCount),
                    indexed.surah.revelationType == RevelationType.meccan
                        ? AppLocalizations.of(context).quranMeccan
                        : AppLocalizations.of(context).quranMedinan,
                    // The Arabic name, unless it is already the title.
                    if (indexed.arabicName != null &&
                        indexed.arabicName != indexed.localizedName)
                      indexed.arabicName!,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
                    child: TahfeezQuranSectionCard(
                      number: indexed.surah.surahNo,
                      title:
                          indexed.localizedName ??
                          AppLocalizations.of(context)
                              .homeContinueReadingSurah(indexed.surah.surahNo),
                      subtitle: subtitleParts.join(' · '),
                      footer: switch (progress[indexed.surah.surahNo]) {
                        final p? => _SurahProgressBars(progress: p),
                        null => null,
                      },
                      onTap: () => widget.onSelect(
                        QuranLocation.surah(indexed.surah.surahNo),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const TahfeezLoadingView(),
            error: (_, _) => TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: AppLocalizations.of(context)
                  .homeQuranDatasetUnavailableBody,
            ),
          ),
        ),
      ],
    );
  }
}

/// A surah's memorization (share memorized) and tajweed (its ayahs' latest
/// recitations), as two thin bars.
class _SurahProgressBars extends StatelessWidget {
  const _SurahProgressBars({required this.progress});

  final SurahProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const ValueKey('surah-progress'),
      spacing: TahfeezSpacing.md,
      children: [
        Expanded(
          child: ScoreBar(
            label: l10n.memScoreMemorization,
            value: progress.memorization,
            dense: true,
          ),
        ),
        Expanded(
          child: progress.tajweed == null
              ? const SizedBox.shrink()
              : ScoreBar(
                  label: l10n.memScoreTajweed,
                  value: progress.tajweed!,
                  dense: true,
                ),
        ),
      ],
    );
  }
}
