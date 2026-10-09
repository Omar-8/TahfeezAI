import 'models/memorization_models.dart';
import 'strength_model.dart';

/// A run of consecutive ayahs to recite (stable ayah ids, in Quran order).
class RevisionTask {
  const RevisionTask({
    required this.ayahIds,
    this.page,
    this.strength,
    this.unverified = false,
    this.done = false,
  });

  /// The ayahs, consecutive, in order.
  final List<int> ayahIds;

  /// The Mushaf page (old revision is by page).
  final int? page;

  /// The weakest tested ayah's strength (0-1); `null` when none is tested.
  final double? strength;

  /// Holds ayahs marked as already known, not yet recited in the app.
  final bool unverified;

  /// Every ayah in it was reviewed today.
  final bool done;

  int get first => ayahIds.first;
  int get last => ayahIds.last;

  @override
  String toString() =>
      'RevisionTask($first-$last, page $page, strength $strength, '
      'unverified $unverified, done $done)';
}

/// Today's memorization: the three parts of a Hifz day.
class TodayPlan {
  const TodayPlan({this.recent = const [], this.old = const []});

  /// Recent revision (sabqi): what is being learned or was learned lately.
  final List<RevisionTask> recent;

  /// Old revision (manzil): pages of what was memorized before, weakest
  /// first.
  final List<RevisionTask> old;

  bool get isEmpty => recent.isEmpty && old.isEmpty;
}

/// Builds [TodayPlan]s (`docs/MEMORIZATION_MILESTONE.md`).
abstract final class TodayScheduler {
  /// What counts as recently learned.
  static const recentDays = 7;

  /// Old revision cycles through everything memorized in about this many
  /// days; a day holds between [minOldPages] and [maxOldPages] pages.
  static const cycleDays = 14, minOldPages = 2, maxOldPages = 20;

  /// Today's plan from [memories] at [now]; [pages] gives each ayah's Mushaf
  /// page (by stable ayah id).
  static TodayPlan plan({
    required Map<int, AyahMemory> memories,
    required Map<int, int> pages,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    bool reviewedToday(AyahMemory m) =>
        m.lastReviewed != null && !m.lastReviewed!.isBefore(today);
    bool recent(AyahMemory m) =>
        m.status == MemoryStatus.learning ||
        (m.learnedOn != null &&
            now.difference(m.learnedOn!).inDays < recentDays);

    // Every ayah in Quran order: stable ids sort that way (surah * 1000 +
    // ayah), and [pages] holds them all.
    final order = pages.keys.toList()..sort();
    final index = {for (var i = 0; i < order.length; i++) order[i]: i};

    RevisionTask task(List<int> ayahs, {int? page}) {
      final ms = [for (final a in ayahs) memories[a]!];
      final strengths = [for (final m in ms) ?StrengthModel.strength(m, now)];
      return RevisionTask(
        ayahIds: ayahs,
        page: page,
        strength: strengths.isEmpty
            ? null
            : strengths.reduce((a, b) => a < b ? a : b),
        unverified: ms.any((m) => !m.verified),
        done: ms.every(reviewedToday),
      );
    }

    // Recent: consecutive runs.
    final recentIds = [
      for (final m in memories.values)
        if (recent(m) && index.containsKey(m.ayahId)) m.ayahId,
    ]..sort();
    final runs = <List<int>>[];
    for (final a in recentIds) {
      if (runs.isNotEmpty && index[runs.last.last]! + 1 == index[a]) {
        runs.last.add(a);
      } else {
        runs.add([a]);
      }
    }

    // Old: by page; the unverified first, then the weakest, then the least
    // recently reviewed.
    final byPage = <int, List<int>>{};
    for (final m in memories.values) {
      if (m.status != MemoryStatus.memorized || recent(m)) continue;
      final page = pages[m.ayahId];
      if (page != null) (byPage[page] ??= []).add(m.ayahId);
    }
    final candidates = [
      for (final MapEntry(key: page, value: ayahs) in byPage.entries)
        task(ayahs..sort(), page: page),
    ];
    final budget = (byPage.length / cycleDays).ceil().clamp(
      minOldPages,
      maxOldPages,
    );
    DateTime lastReview(RevisionTask t) => t.ayahIds
        .map((a) => memories[a]!.lastReviewed ?? DateTime(0))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final waiting = candidates.where((t) => !t.done).toList()
      ..sort((a, b) {
        if (a.unverified != b.unverified) return a.unverified ? -1 : 1;
        final sa = a.strength ?? 0, sb = b.strength ?? 0;
        if (sa != sb) return sa.compareTo(sb);
        return lastReview(a).compareTo(lastReview(b));
      });
    final doneToday = candidates.where((t) => t.done).toList();
    final old = [
      ...waiting.take((budget - doneToday.length).clamp(0, budget)),
      ...doneToday,
    ];
    return TodayPlan(recent: [for (final r in runs) task(r)], old: old);
  }
}
