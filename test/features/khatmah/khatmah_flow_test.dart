import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/khatmah/presentation/khatmah_section.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/similar_ayahs_section.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/quran/application/similar_ayahs_provider.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/similar_ayahs.dart';

import '../../test_helpers/memory_storage.dart';
import '../../test_helpers/widget_test_overrides.dart';

/// Where today's features lead: the khatmah's Read opens the Mushaf at the
/// next page of today's share (Read on: the next page not read at all), a
/// similar ayah opens itself — each on Home's own tab.
void main() {
  const mushaf = Mushaf(
    id: 1,
    code: 'madinah',
    scriptId: 1,
    pageCount: 604,
    linesPerPage: 15,
    qiraah: 'Hafs',
    edition: 'Test',
    renderingType: MushafRenderingType.unicodeText,
  );

  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, Widget home) async {
    container = ProviderContainer(
      overrides: [
        ...tahfeezWidgetTestOverrides(),
        browserStorageProvider.overrideWithValue(MemoryStorage()),
        memorizationClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 12, 9),
        ),
        defaultMushafProvider.overrideWith((ref) async => mushaf),
        ayahLookAlikesProvider.overrideWith(
          (ref, _) => [
            SimilarAyah(
              ayahId: 2123,
              score: 81,
              differ: const {1},
              otherDiffer: const {},
            ),
          ],
        ),
        ayahCanonicalWordsProvider.overrideWith(
          (ref, id) async => [
            AyahWord(
              ayahId: id,
              scriptId: 1,
              wordIndex: 0,
              text: 'وَٱتَّقُوا۟',
            ),
            AyahWord(ayahId: id, scriptId: 1, wordIndex: 1, text: 'يَوْمًا'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              Scaffold(body: SingleChildScrollView(child: home)),
          routes: [
            GoRoute(
              path: 'page/:m/:p',
              builder: (context, state) =>
                  Text('page ${state.pathParameters['p']}'),
            ),
            GoRoute(
              path: 'ayah/:s/:v',
              builder: (context, state) => Text(
                'ayah ${state.pathParameters['s']}:'
                '${state.pathParameters['v']}',
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Read: the first page of today\'s share not read', (
    tester,
  ) async {
    await pump(tester, const HomeKhatmahSection());
    final k = container.read(khatmahProvider.notifier);
    await container.read(khatmahProvider.future);
    await k.start(30);
    await k.readThrough(7);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('khatmah-read')));
    await tester.pumpAndSettle();
    expect(find.text('page 8'), findsOne);
  });

  testWidgets('Read on, today done: the next page not read at all', (
    tester,
  ) async {
    await pump(tester, const HomeKhatmahSection());
    final k = container.read(khatmahProvider.notifier);
    await container.read(khatmahProvider.future);
    await k.start(30);
    await k.readThrough(21);
    await k.read([23]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('khatmah-read-on')));
    await tester.pumpAndSettle();
    expect(find.text('page 22'), findsOne);
  });

  testWidgets('a similar ayah tapped: its sheet closes, it opens', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (context) => const SingleChildScrollView(
              child: SimilarAyahsSection(ayahId: 2048),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('similar-ayah-2123')));
    await tester.pumpAndSettle();
    expect(find.text('ayah 2:123'), findsOne);
    expect(find.byType(SimilarAyahsSection), findsNothing);
  });
}
