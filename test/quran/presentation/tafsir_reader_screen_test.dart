import 'dart:async';

import 'package:drift/native.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/routing/app_routes.dart';
import 'package:tahfeez_ai/core/routing/tafsir_routing.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/quran/application/tafsir_reader_preferences.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/presentation/tafsir_reader_screen.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';

import '../../test_helpers/fake_audio_controller.dart';
import '../quran_test_fixtures.dart';
import '../translation_tafsir_test_fixtures.dart';

void main() {
  Widget wrap(
    QuranDatabase db,
    TafsirDatabase tafsirDb, {
    String? activeTafsirId,
    TafsirReaderPreferences? view,
    String at = '1/1',
    FakeAudioController? audio,
  }) {
    final router = GoRouter(
      initialLocation: '${AppRoutes.tafsir}/$at',
      routes: [
        ...tafsirRoutes(),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const TafsirReaderScreen(chapterNo: 1, verseNo: 1),
        ),
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        tafsirDatabaseProvider.overrideWith((ref) => tafsirDb),
        if (activeTafsirId != null)
          tafsirSelectionControllerProvider.overrideWith(
            () => _FixedActiveTafsir(activeTafsirId),
          ),
        if (view != null)
          tafsirReaderPreferencesProvider.overrideWith(() => _FixedView(view)),
        if (audio != null) ...[
          audioControllerProvider.overrideWithValue(audio),
          defaultMushafProvider.overrideWith((ref) async => null),
        ],
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('shows an install hint with no active tafsir', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);

    await tester.pumpWidget(wrap(db, tafsirDb));
    await tester.pumpAndSettle();

    expect(find.textContaining('Install and select a tafsir'), findsOneWidget);
  });

  testWidgets('shows the active tafsir\'s commentary and source', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(wrap(db, tafsirDb, activeTafsirId: testTafsirId));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test commentary for verse 1'), findsOneWidget);
    expect(find.textContaining('Test Tafsir'), findsOneWidget);
  });

  testWidgets('next steps to the following verse', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(wrap(db, tafsirDb, activeTafsirId: testTafsirId));
    await tester.pumpAndSettle();

    expect(find.text('Tafsir · 1:1'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Tafsir · 1:2'), findsOneWidget);
    expect(find.textContaining('Test commentary for verse 2'), findsOneWidget);
  });

  testWidgets('continuous: ayah after ayah in one scroll, no previous / '
      'next', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(
      wrap(
        db,
        tafsirDb,
        activeTafsirId: testTafsirId,
        view: const TafsirReaderPreferences(
          layout: TafsirLayout.continuous,
          showTranslation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tafsir-continuous')), findsOneWidget);
    expect(find.byKey(const ValueKey('tafsir-ref-1:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tafsir-ref-1:2')), findsOneWidget);
    expect(find.textContaining('Test commentary for verse 1'), findsOneWidget);
    expect(find.textContaining('Test commentary for verse 2'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('continuous, opened mid-surah: the earlier ayahs above, '
      'reached by scrolling up', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await tester.pumpWidget(
      wrap(
        db,
        tafsirDb,
        activeTafsirId: testTafsirId,
        at: '1/2',
        view: const TafsirReaderPreferences(
          layout: TafsirLayout.continuous,
          showTranslation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opened = tester.getTopLeft(
      find.byKey(const ValueKey('tafsir-ref-1:2')),
    );
    expect(opened.dy, lessThan(200), reason: 'opened at 1:2, at the top');
    expect(find.byKey(const ValueKey('tafsir-ref-1:1')), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('tafsir-continuous')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tafsir-ref-1:1')), findsOneWidget);
    expect(find.textContaining('Test commentary for verse 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tafsir-ref-1:1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('tafsir-ref-1:2'))).dy,
      ),
      reason: '1:1 above 1:2',
    );
  });

  testWidgets('continuous: the title follows the ayah at the top', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());
    await tester.pumpWidget(
      wrap(
        db,
        tafsirDb,
        activeTafsirId: testTafsirId,
        view: const TafsirReaderPreferences(
          layout: TafsirLayout.continuous,
          showTranslation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tafsir · 1:1'), findsOneWidget);
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('tafsir-ref-1:2')),
    );
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('tafsir-ref-1:1')),
    );
    await tester.drag(
      find.byKey(const ValueKey('tafsir-continuous')),
      Offset(0, -(second.dy - first.dy)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tafsir · 1:2'), findsOneWidget);
  });

  Future<FakeAudioController> setUpPlaying(
    WidgetTester tester, {
    required TafsirLayout layout,
  }) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(tafsirDb.close);
    final container = ProviderContainer(
      overrides: [tafsirDatabaseProvider.overrideWith((ref) => tafsirDb)],
    );
    addTearDown(container.dispose);
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());
    final audio = FakeAudioController();
    await tester.pumpWidget(
      wrap(
        db,
        tafsirDb,
        activeTafsirId: testTafsirId,
        audio: audio,
        view: TafsirReaderPreferences(layout: layout, showTranslation: false),
      ),
    );
    await tester.pumpAndSettle();
    return audio;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  testWidgets('play the ayah: highlighted, with the player bar to pause or '
      'stop it', (tester) async {
    await setUpPlaying(tester, layout: TafsirLayout.paged);
    expect(find.byKey(const ValueKey('tafsir-player')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tafsir-play-1001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tafsir-player')), findsOneWidget);
    expect(find.byKey(const ValueKey('tafsir-block-playing')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tafsir-player-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tafsir-player')), findsNothing);
  });

  testWidgets('one ayah at a time: on to the ayah the reciter reaches', (
    tester,
  ) async {
    final audio = await setUpPlaying(tester, layout: TafsirLayout.paged);
    unawaited(
      containerOf(tester)
          .read(quranAudioPlayerProvider.notifier)
          .playRange(1001, 1002),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Tafsir · 1:1'), findsOneWidget);
    audio.advanceTo(1);
    await tester.pumpAndSettle();
    expect(find.text('Tafsir · 1:2'), findsOneWidget);
    expect(find.byKey(const ValueKey('tafsir-player')), findsOneWidget);
  });

  testWidgets("continuous: the reciter's ayah highlighted and kept in view", (
    tester,
  ) async {
    final audio = await setUpPlaying(tester, layout: TafsirLayout.continuous);
    unawaited(
      containerOf(tester)
          .read(quranAudioPlayerProvider.notifier)
          .playRange(1001, 1002),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    audio.advanceTo(1);
    await tester.pumpAndSettle();
    final playing = find.byKey(const ValueKey('tafsir-block-playing'));
    expect(playing, findsOneWidget);
    expect(
      tester.getTopLeft(playing).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('tafsir-ref-1:2'))).dy,
      ),
      reason: "1:2's ayah, under its reference",
    );
  });
}

class _FixedView extends TafsirReaderPreferencesController {
  _FixedView(this._view);

  final TafsirReaderPreferences _view;

  @override
  TafsirReaderPreferences build() => _view;
}

class _FixedActiveTafsir extends TafsirSelectionController {
  _FixedActiveTafsir(this._fixed);

  final String _fixed;

  @override
  String? build() => _fixed;
}
