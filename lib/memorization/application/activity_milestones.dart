import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import '../domain/milestones.dart';
import 'activity_stats.dart';
import 'memorization_progress.dart' show milestoneProvider;

/// The lifetime counts reached — ayahs and words recited, days in the
/// Mushaf ([Milestones.activity]) — each celebrated once, as it is crossed
/// (owner, 2026-11-15): the highest of each kind if several at once. Those
/// already reached when this first looks are remembered without a word
/// (an update with years of counts behind it is not news).
class ActivityMilestonesController extends Notifier<void> {
  static const storageKey = 'milestones.activity.v1';

  Set<String>? _seen;
  var _checking = Future<void>.value();

  @override
  void build() {
    ref.listen(activityStatsProvider, (_, stats) {
      // (Only once the saved totals are in: before, a run's counts alone.)
      if (!ref.read(activityStatsProvider.notifier).restored) return;
      _checking = _checking.then((_) => _check(stats));
    }, fireImmediately: true);
  }

  Future<void> _check(ActivityStats stats) async {
    final reached = Milestones.activity(
      recitedAyahs: stats.recitedAyahs,
      recitedWords: stats.recitedWords,
      mushafSeconds: stats.mushafSeconds,
    );
    final storage = ref.read(browserStorageProvider);
    var seen = _seen;
    if (seen == null) {
      final raw = await storage.getString(storageKey);
      if (!ref.mounted) return;
      if (raw == null) {
        _seen = {for (final m in reached) m.id};
        await storage.setString(storageKey, jsonEncode(_seen!.toList()));
        return;
      }
      seen = _seen = {...(jsonDecode(raw) as List).cast<String>()};
    }
    final fresh = [
      for (final m in reached)
        if (!seen.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return;
    seen.addAll(fresh.map((m) => m.id));
    await storage.setString(storageKey, jsonEncode(seen.toList()));
    if (!ref.mounted) return;
    // The highest of each kind.
    for (final kind in ActivityKind.values) {
      final top = fresh.where((m) => m.kind == kind).lastOrNull;
      if (top != null) ref.read(milestoneProvider.notifier).celebrate(top);
    }
  }
}

final activityMilestonesProvider =
    NotifierProvider<ActivityMilestonesController, void>(
      ActivityMilestonesController.new,
    );
