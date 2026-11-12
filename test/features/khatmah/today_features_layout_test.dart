import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/khatmah/presentation/khatmah_section.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';
import 'package:tahfeez_ai/features/listen/presentation/reciter_avatar.dart';
import 'package:tahfeez_ai/features/memorize/presentation/milestone_banner.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/similar_ayahs_section.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/milestones.dart';
import 'package:tahfeez_ai/quran/application/similar_ayahs_provider.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/similar_ayahs.dart';

import '../../test_helpers/memory_storage.dart';
import '../../test_helpers/widget_test_overrides.dart';

/// Today's features at their tightest: a small phone (320 wide), text at
/// twice its size, in long languages and right-to-left ones — the khatmah
/// card in each state and its days sheet, the similar ayahs, the reciter's
/// picture beside his name, the celebration card — nothing overflows.
void main() {
  const locales = ['en', 'de', 'ru', 'ar', 'ur', 'ja'];
  const words = [
    'وَٱتَّقُوا۟',
    'يَوْمًا',
    'لَّا',
    'تَجْزِى',
    'نَفْسٌ',
    'عَن',
    'نَّفْسٍ',
    'شَيْـًٔا',
  ];

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    String locale,
    Widget child, {
    double width = 320,
  }) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        ...tahfeezWidgetTestOverrides(),
        browserStorageProvider.overrideWithValue(MemoryStorage()),
        milestonesReachedProvider.overrideWith((ref) async => const []),
        memorizationClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 12, 9),
        ),
        ayahLookAlikesProvider.overrideWith(
          (ref, _) => [
            for (final (id, score) in [(2123, 81), (55016, 100), (3091, 60)])
              SimilarAyah(
                ayahId: id,
                score: score,
                differ: score == 100 ? const {} : const {1, 4},
                otherDiffer: const {},
              ),
            SimilarAyah(
              ayahId: 7161,
              score: 60,
              differ: const {},
              otherDiffer: const {},
            ),
          ],
        ),
        ayahCanonicalWordsProvider.overrideWith(
          (ref, id) async => [
            for (var i = 0; i < words.length; i++)
              AyahWord(ayahId: id, scriptId: 1, wordIndex: i, text: words[i]),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void fits(WidgetTester tester, String what) {
    final e = tester.takeException();
    expect(e, isNull, reason: '$what: $e');
  }

  for (final locale in locales) {
    testWidgets('$locale: the khatmah card in each state, its days sheet', (
      tester,
    ) async {
      await pump(tester, locale, const HomeKhatmahSection());
      fits(tester, 'none yet');
      final k = container.read(khatmahProvider.notifier);
      await container.read(khatmahProvider.future);
      await k.start(30);
      await k.readThrough(9);
      await tester.pumpAndSettle();
      fits(tester, 'in progress');
      await k.readThrough(21);
      await tester.pumpAndSettle();
      fits(tester, 'today done');

      await tester.tap(find.byKey(const ValueKey('khatmah-menu')));
      await tester.pumpAndSettle();
      fits(tester, 'its menu');
      await tester.tap(find.byKey(const ValueKey('khatmah-change-days')));
      await tester.pumpAndSettle();
      fits(tester, 'days sheet');
      await tester.ensureVisible(
        find.byKey(const ValueKey('khatmah-days-other')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-days-other')));
      await tester.pumpAndSettle();
      fits(tester, 'days typed');
      await tester.enterText(
        find.byKey(const ValueKey('khatmah-days-field')),
        '1234',
      );
      await tester.tap(find.byKey(const ValueKey('khatmah-days-field-save')));
      await tester.pumpAndSettle();
      fits(tester, 'days sheet, 1234 days');
      await tester.ensureVisible(
        find.byKey(const ValueKey('khatmah-days-save')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('khatmah-days-save')));
      await tester.pumpAndSettle();

      await k.readThrough(604);
      await tester.pumpAndSettle();
      fits(tester, 'complete');
    });

    testWidgets('$locale: the similar ayahs', (tester) async {
      await pump(tester, locale, const SimilarAyahsSection(ayahId: 2048));
      fits(tester, 'similar ayahs');
      await tester.tap(find.byKey(const ValueKey('similar-ayahs-all')));
      await tester.pumpAndSettle();
      fits(tester, 'all similar ayahs');
    });

    testWidgets('$locale: a long reciter name beside his picture', (
      tester,
    ) async {
      final r = reciters.firstWhere((r) => r.edition == 'ar.abdullahbasfar');
      await pump(
        tester,
        locale,
        Column(
          children: [
            for (final e in ['ar.minshawi', 'ar.husarymuallim', r.edition])
              ReciterNameWithAvatar(
                reciter: reciters.firstWhere((x) => x.edition == e),
                name: '${r.nameEn} ${r.nameAr} ${r.nameEn}',
              ),
          ],
        ),
      );
      fits(tester, 'reciter names');
    });

    testWidgets('$locale: "Khatmah complete" over a screen, with stars', (
      tester,
    ) async {
      await pump(
        tester,
        locale,
        const SizedBox(
          height: 560,
          child: MilestoneLayer(child: SizedBox.expand()),
        ),
      );
      container
          .read(milestoneProvider.notifier)
          .celebrate(const KhatmahMilestone('2026-10-12'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      fits(tester, 'the card');
      expect(find.byType(TahfeezCelebration), findsOne);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });
  }
}
