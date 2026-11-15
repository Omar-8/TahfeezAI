import 'dart:async';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quran/presentation/tabs/topics_index_tab.dart';
import '../../../quran/application/quran_topics_provider.dart';

import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/quran_dataset_status.dart';
import '../../../quran/domain/models/search_models.dart';
import '../application/search_controller.dart';
import 'widgets/search_filter_sheet.dart';
import 'widgets/search_history_section.dart';
import 'widgets/search_result_sections.dart';
import '../../../quran/presentation/quran_unavailable_view.dart';

/// Tahfeez's search screen — this milestone's "dedicated search
/// field/app bar; filter control; optional voice-search entry; recent
/// history; quick links when empty; ... clear loading/empty/error states"
/// requirement, independently designed (own layout, own components) from
/// `docs/reference/07_SEARCH_SPEC.md` §7's tab/card structure.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _committedQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // refresh the clear-button visibility immediately
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _committedQuery = value);
    });
  }

  void _runSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _debounce?.cancel();
    setState(() => _committedQuery = query);
    _focusNode.unfocus();
  }

  void _onResultTap(SearchHit hit) {
    ref
        .read(searchControllerProvider(_committedQuery).notifier)
        .recordInHistory();
    goToQuranLocation(context, searchHitLocation(hit));
  }

  @override
  Widget build(BuildContext context) {
    final hasDataset =
        ref.watch(hasInstalledQuranDatasetProvider).value ?? false;

    return Scaffold(
      appBar: TahfeezAppBar(
        centerTitle: false,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchHint,
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: AppLocalizations.of(context).quranClear,
                    onPressed: () => _runSearch(''),
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: _runSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).searchFilters,
            onPressed: () => showSearchFilterSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: !hasDataset
            ? const QuranUnavailableView(icon: Icons.search_outlined)
            : _committedQuery.trim().isEmpty
            ? _EmptyQueryBody(onSelectHistory: _runSearch)
            : _ResultsBody(
                query: _committedQuery,
                onResultTap: _onResultTap,
                onClear: () {
                  _controller.clear();
                  _debounce?.cancel();
                  setState(() => _committedQuery = '');
                  _focusNode.requestFocus();
                },
              ),
      ),
    );
  }
}

class _EmptyQueryBody extends StatelessWidget {
  const _EmptyQueryBody({required this.onSelectHistory});

  final ValueChanged<String> onSelectHistory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.lg,
        children: [
          SearchHistorySection(onSelect: onSelectHistory),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TahfeezSpacing.xs,
              children: [
                Text(
                  AppLocalizations.of(context).searchTry,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({
    required this.query,
    required this.onResultTap,
    required this.onClear,
  });

  final String query;
  final ValueChanged<SearchHit> onResultTap;

  /// Nothing found: the field emptied, to search again.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchControllerProvider(query));
    // The Quran tab's Topics named so (owner, 2026-11-15) — above the
    // ayahs found.
    final language = Localizations.localeOf(context).languageCode;
    final topics = ref.watch(quranTopicsProvider).value;
    final topicHits = topics == null || query.trim().length < 2
        ? const <TopicRef>[]
        : [
            for (final group in topics.groups)
              for (final concept in group.concepts)
                if (topicMatches(concept, query, language))
                  (group: group, concept: concept),
          ];

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty && topicHits.isEmpty) {
          return TahfeezEmptyView(
            icon: Icons.search_off_outlined,
            message: AppLocalizations.of(context).searchNoResults(query),
            action: TextButton(
              key: const ValueKey('search-clear'),
              onPressed: onClear,
              child: Text(AppLocalizations.of(context).quranClear),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.md,
            children: [
              if (topicHits.isNotEmpty) _TopicResults(hits: topicHits),
              SearchResultSections(
                results: results,
                query: query,
                onResultTap: onResultTap,
              ),
            ],
          ),
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) =>
          TahfeezErrorView(message: AppLocalizations.of(context).searchError),
    );
  }
}

/// Topics found by name (the Quran tab's): each its group and number of
/// ayahs — tapped, the topic in a sheet. The first few, then "more".
class _TopicResults extends StatefulWidget {
  const _TopicResults({required this.hits});

  final List<TopicRef> hits;

  @override
  State<_TopicResults> createState() => _TopicResultsState();
}

class _TopicResultsState extends State<_TopicResults> {
  static const _first = 5;
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final shown = _all ? widget.hits : widget.hits.take(_first).toList();
    return Column(
      key: const ValueKey('search-topics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TahfeezSectionHeader(
          title: l10n.quranTabTopics,
          icon: Icons.label_outline_rounded,
        ),
        const SizedBox(height: TahfeezSpacing.xs),
        for (final (:group, :concept) in shown)
          TahfeezListRow(
            key: ValueKey('search-topic-${concept.id}'),
            leading: Icon(topicGroupLook(l10n, group.id).$1),
            title: concept.nameIn(language),
            subtitle:
                '${topicGroupLook(l10n, group.id).$2} · '
                '${l10n.topicsAyahs(concept.ayahs.length)}',
            onTap: () => showTopicSheet(context, group, concept),
          ),
        if (!_all && widget.hits.length > _first)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('search-topics-more'),
              onPressed: () => setState(() => _all = true),
              child: Text(l10n.similarAyahsShowAll(widget.hits.length)),
            ),
          ),
      ],
    );
  }
}
