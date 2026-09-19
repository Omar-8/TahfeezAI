import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../quran/domain/models/search_models.dart';

part 'search_history_controller.g.dart';

const _searchHistoryPrefKey = 'search.history';
const _maxHistoryEntries = 20;

/// Recent search queries, most recent first, capped at [_maxHistoryEntries]
/// — this milestone's "search history: persist locally and allow
/// clear/delete behavior" requirement. Persisted as a JSON-encoded list
/// (unlike every other simple `BrowserStorage`-backed preference in this
/// codebase, which stores a single scalar) because history is itself a
/// small ordered collection, not one value.
@Riverpod(keepAlive: true)
class SearchHistoryController extends _$SearchHistoryController {
  @override
  List<SearchHistoryEntry> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_searchHistoryPrefKey);
    if (stored == null) return;
    final decoded = jsonDecode(stored) as List<Object?>;
    state = [
      for (final entry in decoded)
        SearchHistoryEntry(
          query: (entry as Map<String, Object?>)['query']! as String,
          searchedAt: DateTime.fromMillisecondsSinceEpoch(
            entry['searchedAt']! as int,
          ),
        ),
    ];
  }

  Future<void> _persist(List<SearchHistoryEntry> entries) async {
    state = entries;
    await ref
        .read(browserStorageProvider)
        .setString(
          _searchHistoryPrefKey,
          jsonEncode([
            for (final entry in entries)
              {
                'query': entry.query,
                'searchedAt': entry.searchedAt.millisecondsSinceEpoch,
              },
          ]),
        );
  }

  /// Records [query] as the most recent search, moving it to the front if
  /// it was already present (so repeating a search doesn't duplicate it),
  /// then trims to [_maxHistoryEntries].
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final withoutDuplicate = state
        .where((e) => e.query.toLowerCase() != trimmed.toLowerCase())
        .toList();
    final updated = [
      SearchHistoryEntry(query: trimmed, searchedAt: DateTime.now()),
      ...withoutDuplicate,
    ].take(_maxHistoryEntries).toList();
    await _persist(updated);
  }

  Future<void> remove(String query) async {
    await _persist(state.where((e) => e.query != query).toList());
  }

  Future<void> clear() async {
    await _persist(const []);
  }
}
