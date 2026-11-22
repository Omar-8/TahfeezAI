import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../domain/athkar.dart';

/// Today's athkar: how many times each zikr (by id) has been said today.
/// Kept on the phone; a new day starts afresh (owner, 2026-11-21).
class AthkarProgressController extends Notifier<Map<int, int>> {
  static const storageKey = 'athkar.today';

  /// The day [state] counts ("2026-11-21", local time).
  String _day = '';

  String _today() {
    final now = ref.read(memorizationClockProvider)();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  @override
  Map<int, int> build() {
    _day = _today();
    unawaited(_restore());
    return const {};
  }

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    if (raw == null || !ref.mounted) return;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      if (json['day'] != _today()) return;
      final counts = json['counts']! as Map<String, Object?>;
      // (Anything counted meanwhile kept.)
      state = {
        for (final e in counts.entries) int.parse(e.key): e.value! as int,
        ...state,
      };
    } on Object {
      // Unreadable: today starts afresh.
    }
  }

  /// Today's counts — none from an earlier day (the app kept open past
  /// midnight).
  Map<int, int> get _current {
    final day = _today();
    if (day != _day) {
      _day = day;
      state = const {};
    }
    return state;
  }

  /// How many times [zikr] has been said today.
  int countOf(Zikr zikr) => _current[zikr.id] ?? 0;

  bool isDone(Zikr zikr) => countOf(zikr) >= zikr.repeat;

  /// Once more (up to its count). `true` when this finished it.
  bool count(Zikr zikr) {
    final now = countOf(zikr);
    if (now >= zikr.repeat) return false;
    _set({..._current, zikr.id: now + 1});
    return now + 1 == zikr.repeat;
  }

  /// [category]'s athkar from the start again, today.
  void reset(AthkarCategory category) {
    final ids = {for (final z in category.athkar) z.id};
    _set({
      for (final e in _current.entries)
        if (!ids.contains(e.key)) e.key: e.value,
    });
  }

  void _set(Map<int, int> counts) {
    state = counts;
    unawaited(
      ref
          .read(browserStorageProvider)
          .setString(
            storageKey,
            jsonEncode({
              'day': _day,
              'counts': {for (final e in counts.entries) '${e.key}': e.value},
            }),
          ),
    );
  }
}

final athkarProgressProvider =
    NotifierProvider<AthkarProgressController, Map<int, int>>(
      AthkarProgressController.new,
    );

/// How much of [category] is done today: its athkar finished, of all.
({int done, int of}) athkarDone(
  AthkarCategory category,
  Map<int, int> counts,
) => (
  done: category.athkar.where((z) => (counts[z.id] ?? 0) >= z.repeat).length,
  of: category.athkar.length,
);
