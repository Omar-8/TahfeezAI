import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/memorize/presentation/memorize_screen.dart';
import 'package:tahfeez_ai/features/memorize/presentation/test_summary_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
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
  }) => ProviderScope(
    overrides: [
      todayPlanProvider.overrideWith((ref) async => plan),
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
}
