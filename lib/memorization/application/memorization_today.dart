import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/quran/application/quran_index_providers.dart';
import '../../quran/quran_providers.dart';
import '../domain/models/memorization_models.dart';
import '../domain/models/memorization_plan.dart';
import '../domain/plan_scheduler.dart';
import '../domain/recitation_score.dart';
import '../domain/strength_model.dart';
import '../domain/today_scheduler.dart';
import '../memorization_providers.dart';

/// Wall-clock time for memorization; overridden in tests.
final memorizationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Every tracked ayah's memory, live.
final ayahMemoriesProvider = StreamProvider<Map<int, AyahMemory>>(
  (ref) => ref.watch(memorizationRepositoryProvider).watchMemories(),
);

/// Each ayah's page in the default Mushaf (old revision is by page).
final ayahPagesProvider = FutureProvider<Map<int, int>>((ref) async {
  final mushaf = await ref.watch(defaultMushafProvider.future);
  if (mushaf == null) return const {};
  return ref.watch(quranRepositoryProvider).getAyahPages(mushafId: mushaf.id);
});

/// Every test result recorded today, live.
final todayAttemptsProvider = StreamProvider<List<AyahAttempt>>((ref) {
  final now = ref.read(memorizationClockProvider)();
  return ref
      .watch(memorizationRepositoryProvider)
      .watchAttemptsSince(DateTime(now.year, now.month, now.day));
});

/// The active memorization plan, live; `null` without one.
final activePlanProvider = StreamProvider<MemorizationPlan?>(
  (ref) => ref.watch(memorizationRepositoryProvider).watchActivePlan(),
);

/// Today's new lesson from the active plan (`PlanScheduler`); `null`
/// without a plan.
final newLessonProvider = FutureProvider<NewLesson?>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return null;
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final pages = await ref.watch(ayahPagesProvider.future);
  return PlanScheduler.today(
    plan: plan,
    memories: memories,
    pages: pages,
    now: ref.read(memorizationClockProvider)(),
  );
});

/// Today's memorization (`TodayScheduler`).
final todayPlanProvider = FutureProvider<TodayPlan>((ref) async {
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final pages = await ref.watch(ayahPagesProvider.future);
  return TodayScheduler.plan(
    memories: memories,
    pages: pages,
    now: ref.read(memorizationClockProvider)(),
  );
});

/// One graded ayah of a session, with its strength before and after.
class SummaryRow {
  const SummaryRow(this.attempt, {this.before, this.after});

  final AyahAttempt attempt;
  final double? before, after;
}

/// The latest session's graded ayahs (every test of it: a loop's passes
/// too), in order; `null` before any.
class TestSummary {
  const TestSummary(this.sessionId, this.rows);

  final String sessionId;
  final List<SummaryRow> rows;
}

class TestSummaryController extends Notifier<TestSummary?> {
  @override
  TestSummary? build() => null;

  /// Records [attempts] (`MemorizationRepository.recordTest`) and adds them,
  /// with each ayah's strength before and after, to their session's
  /// summary.
  Future<void> record(List<AyahAttempt> attempts) async {
    if (attempts.isEmpty) return;
    final repo = ref.read(memorizationRepositoryProvider);
    final at = attempts.first.at;
    final before = await repo.watchMemories().first;
    await repo.recordTest(attempts);
    final after = await repo.watchMemories().first;
    if (!ref.mounted) return;
    double? strength(AyahMemory? m) =>
        m == null ? null : StrengthModel.strength(m, at);
    final rows = [
      for (final a in attempts)
        SummaryRow(
          a,
          before: strength(before[a.ayahId]),
          after: strength(after[a.ayahId]),
        ),
    ];
    final sessionId = attempts.first.sessionId;
    final current = state;
    state = TestSummary(sessionId, [
      if (current != null && current.sessionId == sessionId) ...current.rows,
      ...rows,
    ]);
  }

  void clear() => state = null;
}

final testSummaryProvider =
    NotifierProvider<TestSummaryController, TestSummary?>(
      TestSummaryController.new,
    );

/// Each ayah's latest test result, live.
final latestAttemptsProvider = StreamProvider<Map<int, AyahAttempt>>(
  (ref) => ref.watch(memorizationRepositoryProvider).watchLatestAttempts(),
);

/// Where a surah stands: how much of it is memorized, and how its ayahs
/// were last recited.
class SurahProgress {
  const SurahProgress({
    required this.ayahs,
    required this.memorized,
    required this.latest,
  });

  final int ayahs, memorized;

  /// Each of its recited ayahs' latest result, together.
  final RecitationScore latest;

  /// The share of its ayahs memorized (0-1).
  double get memorization => ayahs == 0 ? 0 : memorized / ayahs;

  /// Tajweed in its ayahs' latest recitations; `null` before any.
  double? get tajweed => latest.isEmpty ? null : latest.tajweed;
}

/// Every surah with anything memorized or recited, by surah number.
final surahProgressProvider = FutureProvider<Map<int, SurahProgress>>((
  ref,
) async {
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final latest = await ref.watch(latestAttemptsProvider.future);
  final surahs = await ref.watch(indexedSurahsProvider.future);
  final ayahCount = {
    for (final s in surahs) s.surah.surahNo: s.surah.ayahCount,
  };
  final memorized = <int, int>{};
  for (final m in memories.values) {
    if (m.status == MemoryStatus.memorized) {
      memorized.update(m.ayahId ~/ 1000, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final attempts = <int, List<AyahAttempt>>{};
  for (final a in latest.values) {
    (attempts[a.ayahId ~/ 1000] ??= []).add(a);
  }
  return {
    for (final surah in {...memorized.keys, ...attempts.keys})
      surah: SurahProgress(
        ayahs: ayahCount[surah] ?? 0,
        memorized: memorized[surah] ?? 0,
        latest: RecitationScore.of(attempts[surah] ?? const []),
      ),
  };
});
