import 'models/memorization_models.dart';
import 'models/memorization_plan.dart';

/// Today's new lesson from a plan.
class NewLesson {
  const NewLesson({
    this.runs = const [],
    this.done = false,
    this.rest = false,
    this.finished = false,
    required this.memorized,
    required this.total,
  });

  /// The lesson's ayahs as runs of consecutive ayahs (stable ids, in Quran
  /// order within a run; a backward plan may hold more than one run).
  final List<List<int>> runs;

  /// Every ayah of it memorized today.
  final bool done;

  /// Not a study day (and nothing learned today).
  final bool rest;

  /// The whole plan is memorized.
  final bool finished;

  /// The plan's ayahs memorized, of [total].
  final int memorized, total;

  double get progress => total == 0 ? 0 : memorized / total;
}

/// The new lesson (sabaq) of a plan (`docs/MEMORIZATION_MILESTONE.md`, M3).
abstract final class PlanScheduler {
  /// Today's lesson: from the first of the plan's units (in its order) with
  /// an ayah not yet memorized or memorized today, [MemorizationPlan.amount]
  /// units; of them, the ayahs not memorized before today. A missed day
  /// changes nothing: the lesson waits.
  static NewLesson today({
    required MemorizationPlan plan,
    required Map<int, AyahMemory> memories,
    required Map<int, int> pages,
    required DateTime now,
  }) {
    final day = DateTime(now.year, now.month, now.day);
    bool memorized(int a) => memories[a]?.status == MemoryStatus.memorized;
    bool learnedToday(int a) {
      final on = memories[a]?.learnedOn;
      return memorized(a) && on != null && !on.isBefore(day);
    }

    // The plan's ayahs in learning order.
    final order =
        [
          for (final a in pages.keys)
            if (a >= plan.fromAyah && a <= plan.toAyah) a,
        ]..sort(
          (a, b) => plan.backward && a ~/ 1000 != b ~/ 1000
              ? (b ~/ 1000).compareTo(a ~/ 1000)
              : a.compareTo(b),
        );
    final total = order.length;
    final known = order.where(memorized).length;

    // Units: an ayah, a page's ayahs, or each half of a page's ayahs.
    final units = <List<int>>[];
    if (plan.unit == PlanUnit.ayahs) {
      units.addAll([
        for (final a in order) [a],
      ]);
    } else {
      final byPage = <List<int>>[];
      for (final a in order) {
        if (byPage.isNotEmpty && pages[byPage.last.last] == pages[a]) {
          byPage.last.add(a);
        } else {
          byPage.add([a]);
        }
      }
      for (final page in byPage) {
        if (plan.unit == PlanUnit.pages || page.length < 2) {
          units.add(page);
        } else {
          final half = (page.length + 1) ~/ 2;
          units
            ..add(page.sublist(0, half))
            ..add(page.sublist(half));
        }
      }
    }

    final start = units.indexWhere(
      (u) => u.any((a) => !memorized(a) || learnedToday(a)),
    );
    if (start < 0) {
      return NewLesson(finished: true, memorized: known, total: total);
    }
    final lesson = [
      for (final u in units.skip(start).take(plan.amount))
        for (final a in u)
          if (!memorized(a) || learnedToday(a)) a,
    ];
    final anyToday = lesson.any(learnedToday);
    if (!plan.studiesOn(day) && !anyToday) {
      return NewLesson(rest: true, memorized: known, total: total);
    }
    // Runs of ayahs consecutive in the Quran (one surah's end into the next
    // one's start included).
    final quranOrder = pages.keys.toList()..sort();
    final index = {
      for (var i = 0; i < quranOrder.length; i++) quranOrder[i]: i,
    };
    final runs = <List<int>>[];
    for (final a in lesson) {
      final last = runs.isEmpty ? null : runs.last.last;
      final next = last != null && index[a] == index[last]! + 1;
      if (next) {
        runs.last.add(a);
      } else {
        runs.add([a]);
      }
    }
    return NewLesson(
      runs: runs,
      done: lesson.every(learnedToday),
      memorized: known,
      total: total,
    );
  }
}
