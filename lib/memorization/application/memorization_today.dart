import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/quran/application/quran_index_providers.dart';
import '../../quran/quran_providers.dart';
import '../domain/models/memorization_models.dart';
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
