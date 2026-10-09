import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/memorize/presentation/mark_known_sheet.dart';
import 'package:tahfeez_ai/features/memorize/presentation/memorize_screen.dart';
import 'package:tahfeez_ai/features/memorize/presentation/progress_screen.dart';
import 'package:tahfeez_ai/features/memorize/presentation/test_summary_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_plan.dart';
import 'package:tahfeez_ai/memorization/domain/plan_scheduler.dart';
import 'package:tahfeez_ai/memorization/domain/progress_map.dart';
import 'package:tahfeez_ai/memorization/domain/repositories/memorization_repository.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/memorization/domain/today_scheduler.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

void main() {
  final names = [
    for (final (n, name) in const [
      (112, 'Al-Ikhlas'),
      (113, 'Al-Falaq'),
      (114, 'An-Nas'),
    ])
      IndexedSurah(
        surah: Surah(
          surahNo: n,
          ayahCount: 6,
          revelationOrder: n,
          rukusCount: 1,
          revelationType: RevelationType.meccan,
        ),
        arabicName: null,
        localizedName: name,
      ),
  ];

  AyahAttempt attempt(
    int id, {
    AyahGrade? grade,
    int wrong = 0,
    int pronunciation = 0,
  }) => AyahAttempt(
    ayahId: id,
    sessionId: 's',
    at: DateTime(2026),
    grade: grade ?? (wrong > 0 ? AyahGrade.fail : AyahGrade.good),
    words: 10,
    wrong: wrong,
    pronunciation: pronunciation,
  );

  Widget app(
    TodayPlan plan, {
    Widget? child,
    List<AyahAttempt> today = const [],
    MemorizationPlan? memPlan,
    NewLesson? lesson,
    MemorizationRepository? repo,
    List<Override> extra = const [],
  }) => ProviderScope(
    overrides: [
      ...extra,
      todayPlanProvider.overrideWith((ref) async => plan),
      activePlanProvider.overrideWith((ref) => Stream.value(memPlan)),
      newLessonProvider.overrideWith((ref) async => lesson),
      if (repo != null) memorizationRepositoryProvider.overrideWithValue(repo),
      todayAttemptsProvider.overrideWith((ref) => Stream.value(today)),
      indexedSurahsProvider.overrideWith((ref) async => names),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child ?? const MemorizeScreen(),
    ),
  );

  testWidgets('nothing memorized: how to start', (tester) async {
    await tester.pumpWidget(app(const TodayPlan()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to revise yet'), findsOneWidget);
    expect(find.text('Nothing recited yet today'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('today: each part\'s strength, or how today\'s recitation of '
      'it went', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        today: [attempt(114002, wrong: 2, pronunciation: 1)],
        const TodayPlan(
          recent: [
            RevisionTask(ayahIds: [112001, 112002, 112003, 112004]),
          ],
          old: [
            RevisionTask(
              ayahIds: [113001, 113002, 113003, 113004, 113005, 114001],
              page: 604,
              strength: 0.42,
            ),
            RevisionTask(ayahIds: [114002], page: 604, done: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Al-Ikhlas 1–4'), findsOneWidget);
    expect(find.text('Al-Falaq 1 – An-Nas 1'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Start'), findsNWidgets(2));
    // Reviewed today: its scores (8 of 10 words right, 1 of those 8 with a
    // pronunciation mistake), shown for it and for today; recite it again.
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('1 ayah recited today'), findsOneWidget);
    expect(find.text('80%'), findsNWidgets(2));
    expect(find.text('88%'), findsNWidgets(2));
  });

  testWidgets('a session\'s results: an overview, and only the ayahs to '
      'review', (tester) async {
    final summary = TestSummary('s', [
      SummaryRow(attempt(112001), before: 0.5, after: 0.95),
      SummaryRow(attempt(112002, wrong: 3), before: 0.8, after: 0.3),
    ]);
    await tester.pumpWidget(
      app(
        const TodayPlan(),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTestSummarySheet(context, summary),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Session results'), findsOneWidget);
    expect(
      find.text('2 ayahs · 1 good · 0 hesitant · 1 missed'),
      findsOneWidget,
    );
    expect(find.text('85%'), findsOneWidget, reason: '17 of 20 words right');
    expect(find.text('Strength 65% → 63%'), findsOneWidget);
    expect(find.byKey(const ValueKey('mem-weak-112002')), findsOneWidget);
    expect(find.byKey(const ValueKey('mem-weak-112001')), findsNothing);
    expect(find.byKey(const ValueKey('mem-repeat-weak')), findsOneWidget);
  });

  testWidgets('no plan: how to make one; a plan saved from the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _PlanRepository();
    await tester.pumpWidget(app(const TodayPlan(), repo: repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mem-plan-none')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mem-plan-create')));
    await tester.pumpAndSettle();
    expect(find.text('Memorization plan'), findsOneWidget);
    await tester.tap(find.text('Ayahs'));
    // Friday and Saturday off; the last day can't be turned off.
    await tester.tap(find.byKey(const ValueKey('plan-day-5')));
    await tester.tap(find.byKey(const ValueKey('plan-day-6')));
    await tester.pumpAndSettle();
    expect(find.text('5 days a week'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-amount-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-save')));
    await tester.pumpAndSettle();
    final saved = repo.saved;
    expect(saved, isNotNull);
    expect((saved!.fromAyah, saved.toAyah), (78001, 114006));
    expect(
      (saved.unit, saved.amount, saved.backward),
      (PlanUnit.ayahs, 2, true),
    );
    expect(saved.studyDays, {1, 2, 3, 4, 7});
  });

  testWidgets('a plan: today\'s lesson with its progress, or its state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final plan = MemorizationPlan(
      fromAyah: 112001,
      toAyah: 114006,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      app(
        const TodayPlan(),
        memPlan: plan,
        lesson: const NewLesson(
          runs: [
            [114001, 114002, 114003, 114004, 114005, 114006],
            [113001, 113002],
          ],
          memorized: 4,
          total: 16,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4 of 16 ayahs memorized'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('An-Nas 1–6'), findsOneWidget);
    expect(find.text('Al-Falaq 1–2'), findsOneWidget);
    expect(find.text('Start'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(
        const TodayPlan(),
        memPlan: plan,
        lesson: const NewLesson(
          runs: [
            [114001, 114002],
          ],
          rest: true,
          memorized: 4,
          total: 16,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Rest day. You can still learn today\'s lesson.'),
      findsOneWidget,
    );
    expect(find.text('Start'), findsOneWidget);

    // Learned: again, or learn the next lesson too.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(
        const TodayPlan(),
        memPlan: plan,
        lesson: const NewLesson(
          runs: [
            [114001, 114002],
          ],
          more: [
            [114003, 114004],
          ],
          done: true,
          memorized: 6,
          total: 16,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('An-Nas 3–4'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mem-lesson-more')));
    await tester.pumpAndSettle();
    expect(find.text('Next lesson'), findsOneWidget);
    expect(find.text('An-Nas 3–4'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  group('progress (M4)', () {
    final now = DateTime(2026, 10, 9, 18);
    // Al-Ikhlas and Al-Falaq on page 603, An-Nas on 604; all juz 30.
    final pages = <int, int>{
      for (final s in [112, 113])
        for (var a = 1; a <= 6; a++) s * 1000 + a: 603,
      for (var a = 1; a <= 6; a++) 114000 + a: 604,
    };
    final memories = <int, AyahMemory>{
      // Recited 9 days ago at stability 1: strength 50%.
      for (var a = 1; a <= 4; a++)
        112000 + a: AyahMemory(
          ayahId: 112000 + a,
          status: MemoryStatus.memorized,
          stability: 1,
          lastReviewed: now.subtract(const Duration(days: 9)),
        ),
      114001: const AyahMemory(
        ayahId: 114001,
        status: MemoryStatus.memorized,
        verified: false,
      ),
    };
    final map = ProgressMapBuilder.build(
      memories: memories,
      pages: pages,
      juzOfAyah: {for (final a in pages.keys) a: 30},
      now: now,
    );
    List<Override> overrides(Map<int, AyahMemory> memories) => [
      progressMapProvider.overrideWith((ref) async => map),
      ayahMemoriesProvider.overrideWith((ref) => Stream.value(memories)),
      juzAyahsProvider.overrideWith(
        (ref) async => {30: pages.keys.toList()..sort()},
      ),
    ];

    testWidgets('the summary, every page on the map, and the weak pages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const TodayPlan(),
          extra: overrides(memories),
          child: const MemorizationProgressScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('28% of the Quran memorized'), findsOneWidget);
      expect(find.text('5 of 18 ayahs memorized'), findsOneWidget);
      expect(find.text('1 ayah marked, not recited yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('mem-map-page-603')), findsOneWidget);
      expect(find.byKey(const ValueKey('mem-map-page-604')), findsOneWidget);
      // Page 603 at 50%: weak, revised from its memorized ayahs.
      expect(find.byKey(const ValueKey('mem-weak-page-603')), findsOneWidget);
      expect(find.text('Al-Ikhlas 1–4'), findsOneWidget);
      expect(find.byKey(const ValueKey('mem-weak-page-604')), findsNothing);
    });

    testWidgets('marking what is known: checked surahs are marked, unchecked '
        'ones unmarked', (tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _PlanRepository();
      await tester.pumpWidget(
        app(
          const TodayPlan(),
          repo: repo,
          extra: overrides({
            for (var a = 1; a <= 6; a++)
              112000 + a: AyahMemory(
                ayahId: 112000 + a,
                status: MemoryStatus.memorized,
              ),
            114001: const AyahMemory(
              ayahId: 114001,
              status: MemoryStatus.memorized,
            ),
          }),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMarkKnownSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      CheckboxListTile tile(String item) =>
          tester.widget(find.byKey(ValueKey('mark-$item')));
      expect(tile('surah:112').value, isTrue);
      expect(tile('surah:113').value, isFalse);
      expect(tile('surah:114').value, isNull, reason: 'partly memorized');

      await tester.tap(find.byKey(const ValueKey('mark-surah:113')));
      await tester.tap(find.byKey(const ValueKey('mark-surah:112')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mark-save')));
      await tester.pumpAndSettle();
      expect(repo.marked, {for (var a = 1; a <= 6; a++) 113000 + a});
      expect(repo.unmarked, {for (var a = 1; a <= 6; a++) 112000 + a});
    });
  });
}

class _PlanRepository implements MemorizationRepository {
  MemorizationPlan? saved;
  final marked = <int>{}, unmarked = <int>{};

  @override
  Future<void> markMemorized(Iterable<int> ayahIds) async =>
      marked.addAll(ayahIds);

  @override
  Future<void> unmarkUnverified(Iterable<int> ayahIds) async =>
      unmarked.addAll(ayahIds);

  @override
  Future<int> savePlan(MemorizationPlan plan) async {
    saved = plan;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
