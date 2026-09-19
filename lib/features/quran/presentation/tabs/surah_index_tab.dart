import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../../quran/domain/models/surah_models.dart';
import '../../application/quran_index_providers.dart';

enum _RevelationFilter { all, meccan, medinan }

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<IndexedSurah> _apply(List<IndexedSurah> all) {
    final query = _query.trim().toLowerCase();
    return [
      for (final indexed in all)
        if (_matchesFilter(indexed.surah) && _matchesQuery(indexed, query))
          indexed,
    ];
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

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(indexedSurahsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
            TahfeezSpacing.md,
            0,
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search chapters',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Wrap(
            spacing: TahfeezSpacing.sm,
            children: [
              TahfeezFilterChip(
                label: 'All',
                selected: _filter == _RevelationFilter.all,
                onSelected: (_) =>
                    setState(() => _filter = _RevelationFilter.all),
              ),
              TahfeezFilterChip(
                label: 'Meccan',
                selected: _filter == _RevelationFilter.meccan,
                onSelected: (_) =>
                    setState(() => _filter = _RevelationFilter.meccan),
              ),
              TahfeezFilterChip(
                label: 'Medinan',
                selected: _filter == _RevelationFilter.medinan,
                onSelected: (_) =>
                    setState(() => _filter = _RevelationFilter.medinan),
              ),
            ],
          ),
        ),
        Expanded(
          child: surahs.when(
            data: (all) {
              final filtered = _apply(all);
              if (all.isEmpty) {
                return const TahfeezEmptyView(
                  icon: Icons.menu_book_outlined,
                  message: 'This will appear automatically once a Quran dataset is added to the app.',
                );
              }
              if (filtered.isEmpty) {
                return const TahfeezEmptyView(
                  icon: Icons.search_off,
                  message: 'No chapters match your search.',
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
                    '${indexed.surah.ayahCount} ayahs',
                    indexed.surah.revelationType == RevelationType.meccan
                        ? 'Meccan'
                        : 'Medinan',
                    if (indexed.arabicName != null) indexed.arabicName!,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
                    child: TahfeezQuranSectionCard(
                      number: indexed.surah.surahNo,
                      title:
                          indexed.localizedName ??
                          'Surah ${indexed.surah.surahNo}',
                      subtitle: subtitleParts.join(' · '),
                      onTap: () => widget.onSelect(
                        QuranLocation.surah(indexed.surah.surahNo),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const TahfeezLoadingView(),
            error: (_, _) => const TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: 'This will appear automatically once a Quran dataset is added to the app.',
            ),
          ),
        ),
      ],
    );
  }
}
