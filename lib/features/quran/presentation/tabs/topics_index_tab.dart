import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/ui/back_to_exit.dart';
import '../../../../core/ui/bar_space.dart';
import '../../../../core/ui/motion.dart';
import '../../../../core/theme/tahfeez_motion.dart';
import '../../../../quran/application/quran_topics_provider.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../../quran/domain/quran_topics.dart';
import '../../../../quran/domain/search_normalizer.dart';
import '../../../mushaf/application/reader_mode.dart';
import '../../../mushaf/presentation/ayah_view_parts.dart';
import '../../application/quran_index_providers.dart';

/// The Topics tab: the Quran's topics (the Quranic Arabic Corpus's ontology)
/// in a few groups with icons — prophets, peoples, the unseen, the
/// hereafter, places… A group opens its topics, the most mentioned first; a
/// topic its ayahs; an ayah opens in the reader. Back (or the system's)
/// returns a step.
class TopicsIndexTab extends ConsumerStatefulWidget {
  const TopicsIndexTab({super.key, required this.onSelect});

  final ValueChanged<QuranLocation> onSelect;

  @override
  ConsumerState<TopicsIndexTab> createState() => _TopicsIndexTabState();
}

class _TopicsIndexTabState extends ConsumerState<TopicsIndexTab> {
  TopicGroup? _group;
  TopicConcept? _concept;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    BackToExit.claimBack(this, claimed: false);
    _searchController.dispose();
    super.dispose();
  }

  void _back() => setState(() {
    if (_concept != null) {
      _concept = null;
    } else {
      _group = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(quranTopicsProvider);
    return topics.when(
      loading: () => TahfeezGridSkeleton(
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
      ),
      error: (e, _) => TahfeezEmptyView(message: '$e'),
      data: (topics) {
        final group = _group, concept = _concept;
        // A group or topic open: back is this tab's (a step up), not the
        // Quran screen's "back again to leave".
        BackToExit.claimBack(this, claimed: group != null || concept != null);
        final Widget page = concept != null
            ? _ConceptAyahs(
                key: ValueKey('topic-${concept.id}'),
                concept: concept,
                honorific: prophetHonorific(group?.id ?? '', concept.id),
                onBack: _back,
                onSelect: widget.onSelect,
              )
            : group != null
            ? _GroupConcepts(
                key: ValueKey('topic-group-${group.id}'),
                group: group,
                onBack: _back,
                onConcept: (c) => setState(() => _concept = c),
              )
            : Column(
                key: const ValueKey('topic-groups'),
                children: [
                  _TopicsSearchBar(
                    controller: _searchController,
                    query: _query,
                    onChanged: (q) => setState(() => _query = q),
                  ),
                  Expanded(
                    child: _query.trim().isEmpty
                        ? _Groups(
                            topics: topics,
                            onGroup: (g) => setState(() => _group = g),
                          )
                        : _SearchResults(
                            topics: topics,
                            query: _query,
                            onConcept: (g, c) => setState(() {
                              _group = g;
                              _concept = c;
                            }),
                          ),
                  ),
                ],
              );
        return PopScope(
          // Back: a step up (from the groups: as usual).
          canPop: group == null && concept == null,
          onPopInvokedWithResult: (popped, _) {
            if (!popped) _back();
          },
          child: AnimatedSwitcher(
            duration: motion(context, TahfeezMotionDuration.medium),
            child: page,
          ),
        );
      },
    );
  }
}

/// A topic on its own, in a sheet (from an ayah's sheet, or a search):
/// its ayahs and passages as in the Topics tab — one tapped opens it in the
/// Mushaf (a passage highlighted whole).
Future<void> showTopicSheet(
  BuildContext context,
  TopicGroup group,
  TopicConcept concept,
) {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final honorific = prophetHonorific(group.id, concept.id);
  // (Opened from another sheet, the ayah's: an ayah chosen closes them
  // all, and opens from the app's own navigator, which outlives them.)
  final navigator = Navigator.of(context, rootNavigator: true);
  final appContext = navigator.context;
  return showTahfeezModalBottomSheet(
    context: context,
    title: [
      concept.nameIn(language),
      if (honorific != null) honorific.words,
      '· ${l10n.topicsAyahs(concept.ayahs.length)}',
    ].join(' '),
    besideOnWide: true,
    builder: (sheetContext) {
      final runs = ayahRuns(concept.ayahs);
      return ListView.separated(
        key: ValueKey('topic-sheet-${concept.id}'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          TahfeezSpacing.md,
          0,
          TahfeezSpacing.md,
          TahfeezSpacing.lg,
        ),
        itemCount: runs.length,
        separatorBuilder: (_, _) => const SizedBox(height: TahfeezSpacing.xs),
        itemBuilder: (_, i) => _TopicAyah(
          ayahId: runs[i].first,
          lastAyahId: runs[i].last,
          onSelect: (location) {
            navigator.popUntil((route) => route is! PopupRoute);
            goToQuranLocation(appContext, location);
          },
        ),
      );
    },
  );
}

/// The search bar over the groups — as the Surah tab's: a glass pill.
class _TopicsSearchBar extends StatelessWidget {
  const _TopicsSearchBar({
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
          key: const ValueKey('topics-search'),
          controller: controller,
          textAlignVertical: TextAlignVertical.center,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: l10n.topicsSearch,
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

/// Whether [concept] is named [query] in part — in the app's [language],
/// in English, or in Arabic (its letters' forms and marks aside).
bool topicMatches(TopicConcept concept, String query, String language) {
  const normalizer = SearchNormalizer();
  final q = normalizer.normalizeArabic(query);
  if (q.isEmpty) return false;
  return [
    concept.nameIn(language),
    concept.nameIn('en'),
    concept.arabic,
  ].any((name) => normalizer.normalizeArabic(name).contains(q));
}

/// The topics named [query], every group's, each with its group's name.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.topics,
    required this.query,
    required this.onConcept,
  });

  final QuranTopics topics;
  final String query;
  final void Function(TopicGroup, TopicConcept) onConcept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final found = [
      for (final group in topics.groups)
        for (final concept in group.concepts)
          if (topicMatches(concept, query, language)) (group, concept),
    ];
    if (found.isEmpty) {
      return TahfeezEmptyView(message: l10n.searchNoResults(query.trim()));
    }
    return ListView.separated(
      key: const ValueKey('topics-results'),
      padding: withBarSpace(
        context,
        const EdgeInsets.fromLTRB(
          TahfeezSpacing.md,
          TahfeezSpacing.sm,
          TahfeezSpacing.md,
          TahfeezSpacing.md,
        ),
      ),
      itemCount: found.length,
      separatorBuilder: (_, _) => const SizedBox(height: TahfeezSpacing.xs),
      itemBuilder: (context, i) {
        final (group, concept) = found[i];
        return _ConceptCard(
          concept: concept,
          groupId: group.id,
          subtitle:
              '${topicGroupLook(l10n, group.id).$2} · '
              '${l10n.topicsAyahs(concept.ayahs.length)}',
          onTap: () => onConcept(group, concept),
        );
      },
    );
  }
}

/// A group's icon and its name in the app's language.
(IconData, String) topicGroupLook(AppLocalizations l10n, String id) =>
    switch (id) {
      'prophets' => (Icons.record_voice_over_outlined, l10n.topicsProphets),
      'stories' => (Icons.auto_stories_outlined, l10n.topicsStories),
      'people' => (Icons.groups_outlined, l10n.topicsPeople),
      'unseen' => (Icons.auto_awesome_outlined, l10n.topicsUnseen),
      'hereafter' => (Icons.balance_outlined, l10n.topicsHereafter),
      'places' => (Icons.place_outlined, l10n.topicsPlaces),
      'sky' => (Icons.nights_stay_outlined, l10n.topicsSky),
      'nature' => (Icons.eco_outlined, l10n.topicsNature),
      'body' => (Icons.accessibility_new_rounded, l10n.topicsBody),
      'times' => (Icons.event_outlined, l10n.topicsTimes),
      'scriptures' => (Icons.menu_book_outlined, l10n.topicsScriptures),
      'things' => (Icons.category_outlined, l10n.topicsThings),
      _ => (Icons.label_outline, id),
    };

/// An honorific said after a prophet's name: its sign — ﷺ, ﵊ or ﵇, one
/// calligraphic face for all three ([honorificFont]) — and the words it
/// stands for (read aloud).
typedef ProphetHonorific = ({String shown, String words});

/// صلى الله عليه وسلم — after the Prophet Muhammad's name.
const salla = (shown: '\uFDFA', words: 'صلى الله عليه وسلم');

/// عليه الصلاة والسلام — after Ibrahim's, Musa's, Isa's and Nuh's (owner,
/// 2026-11-14): its sign ﵊.
const alayhiSalatu = (shown: '\uFD4A', words: 'عليه الصلاة والسلام');

/// عليه السلام — after every other prophet's: its sign ﵇.
const alayhiSalam = (shown: '\uFD47', words: 'عليه السلام');

/// عليها السلام — after Maryam's (owner, 2026-11-14): its sign ﵍.
const alayhaSalam = (shown: '\uFD4D', words: 'عليها السلام');

/// The face the signs are drawn in: bundled, and has them all (Amiri
/// Quran has only ﷺ).
const honorificFont = 'Noto Naskh Arabic';

/// The honorific after a prophet's name (or Maryam's); else `null`.
ProphetHonorific? prophetHonorific(String groupId, String conceptId) {
  if (groupId == 'people' && conceptId == 'maryam') return alayhaSalam;
  if (groupId != 'prophets') return null;
  return switch (conceptId) {
    'muhammad' => salla,
    'ibrahim' || 'musa' || 'jesus' || 'nuh' => alayhiSalatu,
    _ => alayhiSalam,
  };
}

/// [name], then its honorific's sign — calligraphic, in the accent colour,
/// read aloud as its words.
TextSpan _withHonorific(
  String name,
  ProphetHonorific? honorific,
  TextStyle? style,
  Color color,
) => TextSpan(
  text: name,
  style: style,
  children: [
    if (honorific != null) ...[
      const TextSpan(text: ' '),
      // Isolated, right to left: what follows it keeps its place (a
      // Latin "· 5 ayahs" after it).
      TextSpan(
        text: '\u2067${honorific.shown}\u2069',
        semanticsLabel: honorific.words,
        style: style?.copyWith(
          fontFamily: honorificFont,
          color: color,
          // (Larger than the name's letters: legible.)
          fontSize: (style.fontSize ?? 14) * 1.5,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    ],
  ],
);

class _Groups extends StatelessWidget {
  const _Groups({required this.topics, required this.onGroup});

  final QuranTopics topics;
  final ValueChanged<TopicGroup> onGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: withBarSpace(
            context,
            const EdgeInsets.all(TahfeezSpacing.md),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: scale.scale(200),
                  mainAxisExtent: scale.scale(148),
                  crossAxisSpacing: TahfeezSpacing.sm,
                  mainAxisSpacing: TahfeezSpacing.sm,
                ),
                itemCount: topics.groups.length,
                itemBuilder: (context, i) {
                  final group = topics.groups[i];
                  final (icon, name) = topicGroupLook(l10n, group.id);
                  return TahfeezCard(
                    key: ValueKey('topic-group-card-${group.id}'),
                    onTap: () => onGroup(group),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            icon,
                            size: 22,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              l10n.topicsCount(group.concepts.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: TahfeezSpacing.md),
                  child: Text(
                    l10n.topicsSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A row with a back arrow and a title, over a step's list.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.onBack,
    this.icon,
    this.honorific,
    this.after = '',
  });

  final String title;
  final VoidCallback onBack;
  final IconData? icon;

  /// After [title]: a prophet's honorific, then [after].
  final ProphetHonorific? honorific;
  final String after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TahfeezSpacing.xs,
        TahfeezSpacing.sm,
        TahfeezSpacing.md,
        0,
      ),
      child: Row(
        spacing: TahfeezSpacing.xs,
        children: [
          IconButton(
            key: const ValueKey('topic-back'),
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
          ),
          if (icon != null) Icon(icon, color: theme.colorScheme.primary),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  _withHonorific(
                    title,
                    honorific,
                    theme.textTheme.titleMedium,
                    theme.colorScheme.primary,
                  ),
                  TextSpan(text: after, style: theme.textTheme.titleMedium),
                ],
              ),
              key: const ValueKey('topic-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupConcepts extends StatelessWidget {
  const _GroupConcepts({
    super.key,
    required this.group,
    required this.onBack,
    required this.onConcept,
  });

  final TopicGroup group;
  final VoidCallback onBack;
  final ValueChanged<TopicConcept> onConcept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, name) = topicGroupLook(l10n, group.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(title: name, icon: icon, onBack: onBack),
        Expanded(
          child: ListView.separated(
            padding: withBarSpace(
              context,
              const EdgeInsets.fromLTRB(
                TahfeezSpacing.md,
                TahfeezSpacing.sm,
                TahfeezSpacing.md,
                TahfeezSpacing.md,
              ),
            ),
            itemCount: group.concepts.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: TahfeezSpacing.xs),
            itemBuilder: (context, i) => _ConceptCard(
              concept: group.concepts[i],
              groupId: group.id,
              onTap: () => onConcept(group.concepts[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A topic's card: its name in the app's language (and [subtitle], or its
/// count of ayahs), its Quranic name at the card's end with a prophet's
/// sign.
class _ConceptCard extends StatelessWidget {
  const _ConceptCard({
    required this.concept,
    required this.groupId,
    required this.onTap,
    this.subtitle,
  });

  final TopicConcept concept;
  final String groupId;
  final VoidCallback onTap;

  /// Under its name instead of its count (a search's: its group too).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final own = concept.nameIn(language);
    final honorific = prophetHonorific(groupId, concept.id);
    // Its Quranic name at the card's end, in every language (in
    // Arabic, unless the same as its name) — its sign beside it.
    final showArabic =
        concept.arabic.isNotEmpty &&
        (language != 'ar' || concept.arabic != own);
    return TahfeezCard(
      key: ValueKey('topic-concept-${concept.id}'),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.md,
        vertical: TahfeezSpacing.smPlus,
      ),
      child: Row(
        spacing: TahfeezSpacing.md,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  _withHonorific(
                    own,
                    showArabic ? null : honorific,
                    theme.textTheme.titleSmall,
                    theme.colorScheme.primary,
                  ),
                  key: ValueKey('topic-name-${concept.id}'),
                ),
                Text(
                  subtitle ?? l10n.topicsAyahs(concept.ayahs.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (showArabic)
            Flexible(
              flex: 2,
              fit: FlexFit.tight,
              child: Text.rich(
                // Right to left: the sign to the name's left.
                _withHonorific(
                  concept.arabic,
                  honorific,
                  theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  theme.colorScheme.primary,
                ),
                key: ValueKey('topic-arabic-${concept.id}'),
                textDirection: TextDirection.rtl,
                // The card's end (its own end, right to left,
                // would be the left).
                textAlign: Directionality.of(context) == TextDirection.ltr
                    ? TextAlign.right
                    : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConceptAyahs extends ConsumerWidget {
  const _ConceptAyahs({
    super.key,
    required this.concept,
    required this.onBack,
    required this.onSelect,
    this.honorific,
  });

  final TopicConcept concept;

  /// Said after its name: a prophet's ([prophetHonorific]).
  final ProphetHonorific? honorific;
  final VoidCallback onBack;
  final ValueChanged<QuranLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final own = concept.nameIn(language);
    final runs = ayahRuns(concept.ayahs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          title: own,
          honorific: honorific,
          after: ' · ${l10n.topicsAyahs(concept.ayahs.length)}',
          onBack: onBack,
        ),
        Expanded(
          child: ListView.separated(
            padding: withBarSpace(
              context,
              const EdgeInsets.fromLTRB(
                TahfeezSpacing.md,
                TahfeezSpacing.sm,
                TahfeezSpacing.md,
                TahfeezSpacing.md,
              ),
            ),
            itemCount: runs.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: TahfeezSpacing.xs),
            itemBuilder: (context, i) => _TopicAyah(
              ayahId: runs[i].first,
              lastAyahId: runs[i].last,
              onSelect: onSelect,
            ),
          ),
        ),
      ],
    );
  }
}

/// [ayahs] (sorted ids) as runs of ayahs one after another in a surah —
/// a passage one card, its first and last ayah shown.
List<({int first, int last})> ayahRuns(List<int> ayahs) {
  final runs = <({int first, int last})>[];
  for (final id in ayahs) {
    final run = runs.lastOrNull;
    if (run != null && id == run.last + 1) {
      runs[runs.length - 1] = (first: run.first, last: id);
    } else {
      runs.add((first: id, last: id));
    }
  }
  return runs;
}

/// An ayah of a topic — or a passage, ayahs one after another (its first
/// and last, "from … to"): where it is, and its words (the app's own text).
/// Opened, the passage is highlighted whole.
class _TopicAyah extends ConsumerWidget {
  const _TopicAyah({
    required this.ayahId,
    required this.lastAyahId,
    required this.onSelect,
  });

  final int ayahId;
  final int lastAyahId;
  final ValueChanged<QuranLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chapterNo = ayahId ~/ 1000, verseNo = ayahId % 1000;
    final lastVerseNo = lastAyahId % 1000;
    final passage = lastAyahId != ayahId;
    final surahName = [
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        if (s.surah.surahNo == chapterNo) s.localizedName ?? s.arabicName,
    ].firstOrNull;
    final String where;
    if (!passage) {
      where = surahName == null
          ? '$chapterNo:$verseNo'
          : l10n.homeDailyAyahReferenceNamed(surahName, verseNo);
    } else {
      where =
          '${surahName ?? chapterNo} $verseNo–$lastVerseNo · '
          '${l10n.topicsAyahs(lastVerseNo - verseNo + 1)}';
    }
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    Widget text(int id) {
      final words = ref.watch(ayahCanonicalWordsProvider(id)).value;
      if (words == null) return const SizedBox.shrink();
      return Text(
        [for (final w in words) w.text].join(' '),
        textDirection: TextDirection.rtl,
        maxLines: passage ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: font,
          fontSize: 20,
          height: 1.9,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    return TahfeezCard(
      key: ValueKey(
        passage ? 'topic-passage-$ayahId-$lastAyahId' : 'topic-ayah-$ayahId',
      ),
      onTap: () => onSelect(
        passage
            ? QuranLocation.ayahRange(chapterNo, verseNo, lastVerseNo)
            : QuranLocation.ayah(chapterNo, verseNo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.xs,
        children: [
          Row(
            spacing: TahfeezSpacing.xs,
            children: [
              if (passage)
                Icon(
                  Icons.format_line_spacing_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              Expanded(
                child: Text(
                  where,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: passage
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          text(ayahId),
          if (passage) ...[
            // From the first to the last: the ayahs between.
            Row(
              children: [
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TahfeezSpacing.sm,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
              ],
            ),
            text(lastAyahId),
          ],
        ],
      ),
    );
  }
}
