import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../quran/domain/models/search_models.dart';

part 'search_filters_controller.g.dart';

const _searchFiltersPrefKey = 'search.filters';

/// Which search domains/translations a query runs against — this
/// milestone's "filter control" requirement. Persisted as a small
/// JSON-encoded object, since [SearchFilters] has more than one field.
/// Defaults to every domain enabled and every installed translation
/// included (`translationSlugs: null`), matching
/// `docs/reference/07_SEARCH_SPEC.md` §5's "null/empty means search across
/// all installed translations."
@Riverpod(keepAlive: true)
class SearchFiltersController extends _$SearchFiltersController {
  @override
  SearchFilters build() {
    _restore();
    return const SearchFilters();
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_searchFiltersPrefKey);
    if (stored == null) return;
    final decoded = jsonDecode(stored) as Map<String, Object?>;
    final slugsJson = decoded['translationSlugs'] as List<Object?>?;
    state = SearchFilters(
      includeArabicText: decoded['includeArabicText']! as bool,
      includeSurahs: decoded['includeSurahs']! as bool,
      translationSlugs: slugsJson?.cast<String>().toSet(),
    );
  }

  Future<void> update(SearchFilters filters) async {
    state = filters;
    await ref
        .read(browserStorageProvider)
        .setString(
          _searchFiltersPrefKey,
          jsonEncode({
            'includeArabicText': filters.includeArabicText,
            'includeSurahs': filters.includeSurahs,
            'translationSlugs': filters.translationSlugs?.toList(),
          }),
        );
  }
}
