import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../../core/ui/bar_space.dart';
import '../../../quran/domain/search_normalizer.dart';
import '../../home/presentation/home_sky.dart';
import '../application/athkar_progress.dart';
import '../data/athkar_source.dart';
import '../domain/athkar.dart';
import 'athkar_look.dart';
import 'athkar_reminder_sheet.dart';

/// Athkar (from Home and the side menu — owner, 2026-11-21): Hisn
/// al-Muslim's chapters as tiles, each with its icon, in sections; searched
/// as the Topics are (a chapter's title or any of its athkar).
class AthkarScreen extends ConsumerStatefulWidget {
  const AthkarScreen({super.key});

  @override
  ConsumerState<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends ConsumerState<AthkarScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(athkarBookProvider);
    return SkyBackdrop(
      child: Scaffold(
        appBar: TahfeezAppBar(
          title: Text(l10n.athkarTitle),
          centerTitle: false,
          actions: [
            IconButton(
              key: const ValueKey('athkar-reminders'),
              tooltip: l10n.athkarReminders,
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => showAthkarReminderSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TahfeezContentWidth.maxReading,
              ),
              child: Column(
                children: [
                  _SearchBar(
                    controller: _search,
                    query: _query,
                    onChanged: (q) => setState(() => _query = q),
                  ),
                  Expanded(
                    child: switch (book) {
                      AsyncData(:final value) => _Categories(
                        book: value,
                        query: _query,
                      ),
                      AsyncError() => TahfeezErrorView(
                        message: l10n.athkarLoadError,
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        TahfeezSpacing.smPlus,
        TahfeezSpacing.md,
        0,
      ),
      child: TahfeezGlassSurface(
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        child: TextField(
          key: const ValueKey('athkar-search'),
          controller: controller,
          textAlignVertical: TextAlignVertical.center,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: l10n.athkarSearchHint,
            border: InputBorder.none,
            isDense: true,
            constraints: const BoxConstraints(minHeight: 48),
            contentPadding: EdgeInsets.zero,
            prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    tooltip: l10n.quranClear,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Each chapter's words, as searched: its titles and its athkar's text,
/// their letters' forms and marks aside.
final _searchIndexProvider = FutureProvider<Map<int, String>>((ref) async {
  final book = await ref.watch(athkarBookProvider.future);
  const normalizer = SearchNormalizer();
  return {
    for (final c in book.categories)
      c.id: normalizer.normalizeArabic(
        [
          c.arabic,
          c.english,
          ?c.shortArabic,
          ?c.shortEnglish,
          for (final z in c.athkar) ...[z.arabic, z.english, z.note],
        ].join('\n'),
      ),
  };
});

/// Whether [category] is named — or holds a zikr with — [query].
bool athkarMatches(AthkarCategory category, String text, String query) {
  final q = const SearchNormalizer().normalizeArabic(query.trim());
  return q.isNotEmpty && text.contains(q);
}

/// Tiles in a grid, as the Topics' (their size following the text's).
SliverGridDelegate athkarTileGrid(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context);
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: scale.scale(200),
    mainAxisExtent: scale.scale(148),
    crossAxisSpacing: TahfeezSpacing.sm,
    mainAxisSpacing: TahfeezSpacing.sm,
  );
}

/// A page's own name over its content, whole — as many lines as it takes
/// (owner, 2026-11-21: cut short in the top bar).
class AthkarHeading extends StatelessWidget {
  const AthkarHeading(this.text, {super.key, this.full});

  final String text;

  /// The book's own title under it (where [text] is Tahfeez's short one).
  final String? full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            text,
            key: const ValueKey('athkar-heading'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (full != null && full != text)
            Text(
              full!,
              key: const ValueKey('athkar-heading-full'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The Athkar page's content: the sections as tiles (each opening its
/// chapters as tiles — owner, 2026-11-21: no long scroll); searching, the
/// chapters found.
class _Categories extends ConsumerWidget {
  const _Categories({required this.book, required this.query});

  final AthkarBook book;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counts = ref.watch(athkarProgressProvider);
    final searching = query.trim().isNotEmpty;
    final List<Widget> slivers;
    if (searching) {
      final index = ref.watch(_searchIndexProvider).value ?? const {};
      final found = [
        for (final c in book.categories)
          if (athkarMatches(c, index[c.id] ?? '', query)) c,
      ];
      slivers = found.isEmpty
          ? [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: TahfeezSpacing.xl),
                  child: TahfeezEmptyView(
                    message: l10n.searchNoResults(query.trim()),
                  ),
                ),
              ),
            ]
          : [
              SliverGrid.builder(
                gridDelegate: athkarTileGrid(context),
                itemCount: found.length,
                itemBuilder: (context, i) =>
                    AthkarCategoryTile(category: found[i], counts: counts),
              ),
            ];
    } else {
      slivers = [
        // Wide and low, two across: every section in view at once (owner,
        // 2026-11-21), each name with room for its words.
        SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(260),
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(108),
            crossAxisSpacing: TahfeezSpacing.sm,
            mainAxisSpacing: TahfeezSpacing.sm,
          ),
          itemCount: AthkarGroup.values.length,
          itemBuilder: (context, i) =>
              _SectionTile(group: AthkarGroup.values[i], book: book),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: TahfeezSpacing.md),
            child: Text(
              l10n.athkarSource,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }
    return CustomScrollView(
      key: const ValueKey('athkar-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: withBarSpace(
            context,
            const EdgeInsets.all(TahfeezSpacing.md),
          ),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }
}

/// A section (Morning, evening & sleep; Mosque & prayer…): its icon, its
/// name, how many chapters — ticked once all of them are done today.
class _SectionTile extends ConsumerWidget {
  const _SectionTile({required this.group, required this.book});

  final AthkarGroup group;
  final AthkarBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = ref.watch(athkarProgressProvider);
    final chapters = [for (final id in group.categories) ?book.category(id)];
    final started = chapters.where(
      (c) => c.athkar.any((z) => (counts[z.id] ?? 0) > 0),
    );
    final finished = chapters.every((c) {
      final (:done, :of) = athkarDone(c, counts);
      return done == of;
    });
    return TahfeezCard(
      key: ValueKey('athkar-section-${group.name}'),
      padding: const EdgeInsets.all(TahfeezSpacing.sm),
      onTap: () => context.push(AppRoutes.athkarSection(group.name)),
      child: Row(
        spacing: TahfeezSpacing.sm,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(group.icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title(l10n),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.athkarChapters(chapters.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (finished)
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20)
          else if (started.isNotEmpty)
            Icon(Icons.timelapse_rounded, color: scheme.primary, size: 18),
        ],
      ),
    );
  }
}

/// A section's chapters as tiles, under its name.
class AthkarSectionScreen extends ConsumerWidget {
  const AthkarSectionScreen({super.key, required this.group});

  final AthkarGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(athkarBookProvider).value;
    final counts = ref.watch(athkarProgressProvider);
    final chapters = [
      if (book != null)
        for (final id in group.categories) ?book.category(id),
    ];
    return SkyBackdrop(
      child: Scaffold(
        appBar: TahfeezAppBar(
          title: Text(l10n.athkarTitle),
          centerTitle: false,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TahfeezContentWidth.maxReading,
              ),
              child: CustomScrollView(
                key: const ValueKey('athkar-section-list'),
                slivers: [
                  SliverPadding(
                    padding: withBarSpace(
                      context,
                      const EdgeInsets.all(TahfeezSpacing.md),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: AthkarHeading(group.title(l10n)),
                        ),
                        SliverGrid.builder(
                          gridDelegate: athkarTileGrid(context),
                          itemCount: chapters.length,
                          itemBuilder: (context, i) => AthkarCategoryTile(
                            category: chapters[i],
                            counts: counts,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chapter: its icon, its title, how many athkar — and today's progress
/// (ticked once all are done).
class AthkarCategoryTile extends StatelessWidget {
  const AthkarCategoryTile({
    super.key,
    required this.category,
    required this.counts,
  });

  final AthkarCategory category;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final (:done, :of) = athkarDone(category, counts);
    final finished = done == of;
    return TahfeezCard(
      key: ValueKey('athkar-category-${category.id}'),
      onTap: () => context.push(AppRoutes.athkarCategory(category.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: Icon(
                  athkarCategoryIcon(category.id),
                  size: 22,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              if (finished)
                Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('athkar-category-done-${category.id}'),
                  color: scheme.primary,
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.titleIn(language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                done > 0 && !finished
                    ? l10n.athkarDoneOf(done, of)
                    : l10n.athkarCount(of),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: done > 0 ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
