import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';

/// The athkar chapters and duas bookmarked (owner, 2026-11-23): shown first
/// among their tiles, and on the Bookmarks page. Kept on the phone, newest
/// first, by key — `athkar:<chapter id>`, or a Quran dua's
/// `quran:<surah>:<from>-<to>`.
class SavedSupplications extends Notifier<List<String>> {
  static const storageKey = 'supplications.saved';

  /// An athkar chapter's key.
  static String chapterKey(int id) => 'athkar:$id';

  /// The chapter [key] is, or `null` (a Quran dua's).
  static int? chapterOf(String key) =>
      key.startsWith('athkar:') ? int.tryParse(key.substring(7)) : null;

  @override
  List<String> build() {
    unawaited(_restore());
    return const [];
  }

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    if (raw == null || !ref.mounted) return;
    try {
      final kept = [
        for (final k in jsonDecode(raw) as List<Object?>) k! as String,
      ];
      // (Anything saved meanwhile kept, first.)
      state = [...state, ...kept.where((k) => !state.contains(k))];
    } on Object {
      // Unreadable: none.
    }
  }

  bool isSaved(String key) => state.contains(key);

  /// Saved (first) or, when it was, no longer.
  void toggle(String key) => _set(
    state.contains(key)
        ? [
            for (final k in state)
              if (k != key) k,
          ]
        : [key, ...state],
  );

  /// [key] back where it was ([index]) — a removal undone.
  void restore(String key, int index) {
    if (state.contains(key)) return;
    _set([...state]..insert(index.clamp(0, state.length), key));
  }

  void _set(List<String> keys) {
    state = keys;
    unawaited(
      ref.read(browserStorageProvider).setString(storageKey, jsonEncode(keys)),
    );
  }
}

final savedSupplicationsProvider =
    NotifierProvider<SavedSupplications, List<String>>(SavedSupplications.new);

/// [items] with the saved ones first (in their own order otherwise).
List<T> savedFirst<T>(
  List<T> items,
  List<String> saved,
  String Function(T) keyOf,
) => [
  ...items.where((i) => saved.contains(keyOf(i))),
  ...items.where((i) => !saved.contains(keyOf(i))),
];
