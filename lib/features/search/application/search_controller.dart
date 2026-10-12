import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/domain/models/search_models.dart';
import '../../../quran/search_providers.dart';
import '../../../quran/translation_providers.dart';
import 'search_filters_controller.dart';
import 'search_history_controller.dart';
import '../../../quran/application/translation_selection_controller.dart';

part 'search_controller.g.dart';

/// Runs [query] across every enabled search domain, ensuring the Arabic
/// and active-translation search indexes exist first — a `family` provider
/// (one instance per distinct query string), so retyping an already-run
/// query is served from cache rather than re-querying.
///
/// This is also the seam `docs/PROJECT_BRIEF.md`'s future AI features
/// depend on: any future voice-recognition output only ever needs to
/// produce a plain [String] and feed it here exactly the way typed text
/// already does — no separate "voice search" code path exists at the
/// controller level, per this milestone's "Future AI" requirement.
@riverpod
class SearchController extends _$SearchController {
  late String _query;

  @override
  Future<SearchResults> build(String query) async {
    _query = query;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SearchResults();

    final repository = ref.watch(searchRepositoryProvider);
    final scriptCode = ref.watch(quranScriptCodeProvider);
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final filters = ref.watch(searchFiltersControllerProvider);

    if (filters.includeArabicText &&
        !await repository.isQuranTextIndexed(scriptCode: scriptCode)) {
      await repository.indexQuranText(scriptCode: scriptCode);
    }

    // Only index translations this search would actually use.
    final translationRepository = ref.watch(translationRepositoryProvider);
    final installedSlugs =
        (await translationRepository.getInstalledTranslations()).map(
          (book) => book.slug,
        );
    // Without a choice in the filters: the translations chosen in Settings
    // (more can be added in the filters).
    final searched =
        filters.translationSlugs ??
        ref.watch(translationSelectionControllerProvider).toSet();
    final relevantSlugs = installedSlugs.where(searched.contains);
    for (final slug in relevantSlugs) {
      if (!await repository.isTranslationIndexed(slug)) {
        await repository.indexTranslation(slug);
      }
    }

    return repository.search(
      trimmed,
      scriptCode: scriptCode,
      languageCode: languageCode,
      filters: filters.copyWith(translationSlugs: searched),
    );
  }

  /// Records the current query in search history — called once a search
  /// actually produces results worth remembering (the search screen calls
  /// this on submit, not on every keystroke).
  Future<void> recordInHistory() async {
    await ref.read(searchHistoryControllerProvider.notifier).record(_query);
  }
}
