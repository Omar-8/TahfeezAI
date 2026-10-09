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

  Widget app(TodayPlan plan, {Widget? child}) => ProviderScope(
    overrides: [
      todayPlanProvider.overrideWith((ref) async => plan),
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
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('today: recent runs and old pages, with strength and done', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
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
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Start'), findsNWidgets(2));
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a session\'s results: grades, strength, and the weak ayahs to '
      'repeat', (tester) async {
    AyahAttempt a(int id, AyahGrade g) => AyahAttempt(
      ayahId: id,
      sessionId: 's',
      at: DateTime(2026),
      grade: g,
      words: 4,
    );
    final summary = TestSummary('s', [
      SummaryRow(a(112001, AyahGrade.good), before: 0.5, after: 0.95),
      SummaryRow(a(112002, AyahGrade.fail), before: 0.8, after: 0.3),
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
    expect(find.text('50% → 95%'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.byKey(const ValueKey('mem-repeat-weak')), findsOneWidget);
  });
}
