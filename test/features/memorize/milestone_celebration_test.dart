import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/memorize/presentation/milestone_banner.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/milestones.dart';

import '../../test_helpers/memory_storage.dart';
import '../../test_helpers/widget_test_overrides.dart';

/// A surah memorized, a khatmah complete or a lifetime count reached:
/// the khatmah's burst of stars behind the milestone card, under
/// "Masha'Allah"; other milestones: the card only; "remove animations": no
/// burst.
void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {bool noAnimations = false}) async {
    container = ProviderContainer(
      overrides: [
        ...tahfeezWidgetTestOverrides(),
        browserStorageProvider.overrideWithValue(MemoryStorage()),
        milestonesReachedProvider.overrideWith((ref) async => const []),
        memorizationClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 12, 9),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: noAnimations),
            child: child!,
          ),
          home: const MilestoneLayer(child: Scaffold(body: SizedBox())),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> reach(WidgetTester tester, Milestone m) async {
    container.read(milestoneProvider.notifier).celebrate(m);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  bool grand(WidgetTester tester) =>
      tester.widget<TahfeezCelebration>(find.byType(TahfeezCelebration)).grand;

  testWidgets('a surah memorized: the card and a burst of stars', (
    tester,
  ) async {
    await pump(tester);
    await reach(tester, const SurahsMilestone([112]));
    expect(find.byKey(const ValueKey('milestone-banner')), findsOne);
    expect(find.byKey(const ValueKey('celebration')), findsOne);
    expect(grand(tester), isTrue, reason: 'the khatmah\'s burst (2026-11-15)');
    expect(find.text("Masha'Allah"), findsOne);
    // It plays once, then the card goes; nothing stays.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezCelebration), findsNothing);
  });

  testWidgets('a khatmah complete: "Khatmah complete", the grand burst', (
    tester,
  ) async {
    await pump(tester);
    await reach(tester, const KhatmahMilestone('2026-10-12'));
    expect(find.text('Khatmah complete'), findsOne);
    expect(find.byKey(const ValueKey('celebration')), findsOne);
    expect(grand(tester), isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.byKey(const ValueKey('milestone-banner')),
      findsOne,
      reason: 'a khatmah stays 7 s',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  for (final (m, text) in [
    (
      const ActivityMilestone(ActivityKind.ayahs, 10000),
      '10,000 ayahs recited',
    ),
    (
      const ActivityMilestone(ActivityKind.words, 100000),
      '100,000 words recited',
    ),
    (
      const ActivityMilestone(ActivityKind.mushafDays, 1),
      '1 day in the Mushaf',
    ),
    (
      const ActivityMilestone(ActivityKind.mushafDays, 14),
      '14 days in the Mushaf',
    ),
    (
      const ActivityMilestone(ActivityKind.mushafDays, 30),
      '1 month in the Mushaf',
    ),
    (
      const ActivityMilestone(ActivityKind.mushafDays, 180),
      '6 months in the Mushaf',
    ),
    (
      const ActivityMilestone(ActivityKind.mushafDays, 365),
      'A year in the Mushaf',
    ),
  ]) {
    testWidgets('a lifetime count: "$text", Masha\'Allah, the khatmah\'s '
        'burst', (tester) async {
      await pump(tester);
      await reach(tester, m);
      expect(find.text(text), findsOne);
      expect(find.text("Masha'Allah"), findsOne);
      expect(find.byKey(const ValueKey('celebration')), findsOne);
      expect(grand(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a streak: the card, no burst', (tester) async {
    await pump(tester);
    await reach(tester, const StreakMilestone(7));
    expect(find.byKey(const ValueKey('milestone-banner')), findsOne);
    expect(find.byType(TahfeezCelebration), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('"remove animations": the card, no burst painted', (
    tester,
  ) async {
    await pump(tester, noAnimations: true);
    await reach(tester, const SurahsMilestone([112]));
    expect(find.byKey(const ValueKey('milestone-banner')), findsOne);
    expect(find.byKey(const ValueKey('celebration')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('the khatmah\'s last page read: its milestone, once', (
    tester,
  ) async {
    await pump(tester);
    final khatmah = container.read(khatmahProvider.notifier);
    await container.read(khatmahProvider.future);
    await khatmah.start(30);
    await khatmah.readThrough(600);
    expect(container.read(milestoneProvider), isNull);
    await khatmah.readThrough(604);
    expect(container.read(milestoneProvider), isA<KhatmahMilestone>());
    container.read(milestoneProvider.notifier).dismiss();
    await khatmah.read([1]); // already finished: nothing more
    expect(container.read(milestoneProvider), isNull);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });
}
