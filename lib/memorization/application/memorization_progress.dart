import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import '../../quran/domain/models/navigation_models.dart';
import '../../quran/quran_providers.dart';
import '../domain/activity_calendar.dart';
import '../domain/milestones.dart';
import '../domain/progress_map.dart';
import '../memorization_providers.dart';
import 'memorization_today.dart';

/// Each juz's ayahs (stable ids, Quran order), from the dataset's juz
/// ranges.
final juzAyahsProvider = FutureProvider<Map<int, List<int>>>((ref) async {
  final ranges = await ref
      .watch(quranRepositoryProvider)
      .getNavigationRanges(NavigationUnitType.juz);
  final juz = <int, List<int>>{};
  for (final r in ranges) {
    final ayahs = juz[r.unitNo] ??= [];
    for (var a = r.startAyahNo; a <= r.endAyahNo; a++) {
      ayahs.add(r.surahNo * 1000 + a);
    }
  }
  for (final ayahs in juz.values) {
    ayahs.sort();
  }
  return juz;
});

/// The whole Quran's memorization, juz by juz and page by page (M4), live.
final progressMapProvider = FutureProvider<ProgressMap>((ref) async {
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final pages = await ref.watch(ayahPagesProvider.future);
  final juz = await ref.watch(juzAyahsProvider.future);
  return ProgressMapBuilder.build(
    memories: memories,
    pages: pages,
    juzOfAyah: {
      for (final MapEntry(key: j, value: ayahs) in juz.entries)
        for (final a in ayahs) a: j,
    },
    now: ref.read(memorizationClockProvider)(),
  );
});

/// Ayahs recited on each day ever, live.
final dailyRecitedProvider = StreamProvider<Map<DateTime, int>>(
  (ref) => ref.watch(memorizationRepositoryProvider).watchDailyRecited(),
);

/// The days recited, for the streak and the calendar, live.
final activityCalendarProvider = FutureProvider<ActivityCalendar>((ref) async {
  final days = await ref.watch(dailyRecitedProvider.future);
  return ActivityCalendar(days, today: ref.read(memorizationClockProvider)());
});

/// Every milestone reached so far, live.
final milestonesReachedProvider = FutureProvider<List<Milestone>>((ref) async {
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final juz = await ref.watch(juzAyahsProvider.future);
  final calendar = await ref.watch(activityCalendarProvider.future);
  final surahs = await ref.watch(quranRepositoryProvider).getAllSurahs();
  return Milestones.reached(
    memories: memories,
    juzAyahs: juz,
    surahAyahs: {for (final s in surahs) s.surahNo: s.ayahCount},
    totalAyahs: surahs.fold(0, (n, s) => n + s.ayahCount),
    streak: calendar.current,
  );
});

/// The milestone to show now, once — the highest of those newly reached;
/// `null` when none. Those reached before this was first used (an update,
/// a backup restored) are remembered without being shown.
class MilestoneController extends Notifier<Milestone?> {
  static const storageKey = 'milestones.shown.v1';

  Set<String>? _shown;

  @override
  Milestone? build() {
    ref.listen(milestonesReachedProvider, (_, next) {
      final reached = next.value;
      if (reached != null) unawaited(_update(reached));
    }, fireImmediately: true);
    return null;
  }

  Future<void> _update(List<Milestone> reached) async {
    final storage = ref.read(browserStorageProvider);
    var shown = _shown;
    final first = shown == null;
    if (shown == null) {
      final raw = await storage.getString(storageKey);
      if (!ref.mounted) return;
      shown = _shown ??= raw == null
          ? <String>{}
          : {...(jsonDecode(raw) as List).cast<String>()};
      if (raw == null) {
        // Never stored: today's milestones are not news.
        shown.addAll(reached.map((m) => m.id));
        await storage.setString(storageKey, jsonEncode(shown.toList()));
        return;
      }
    }
    final fresh = [
      for (final m in reached)
        if (!shown.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return;
    shown.addAll(fresh.map((m) => m.id));
    await storage.setString(storageKey, jsonEncode(shown.toList()));
    if (!ref.mounted || first && fresh.length > 3) return;
    fresh.sort((a, b) => b.rank - a.rank);
    state = fresh.first;
  }

  /// The milestone shown: no longer pending.
  void dismiss() => state = null;
}

final milestoneProvider = NotifierProvider<MilestoneController, Milestone?>(
  MilestoneController.new,
);
