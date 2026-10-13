import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  Widget wrap(
    QuranDatabase db, {
    QuranLocation location = const QuranLocation.surah(1),
  }) {
    return ProviderScope(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
      child: MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ReaderScreen(location: location),
      ),
    );
  }

  testWidgets('shows an unavailable state with no dataset installed', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This will appear automatically once a Quran dataset is added to the app.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an ayah opens the Mushaf at its page', (tester) async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db, location: const QuranLocation.ayah(1, 3)));
    await tester.pumpAndSettle();

    expect(find.text('Test Chapter One'), findsWidgets);
    expect(find.textContaining('Page 1'), findsOneWidget);
  });

  for (final mode in ReaderMode.values) {
    testWidgets('a surah in ${mode.name} mode: its first ayah asked '
        'into view (the saved mode may not be read back yet)', (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
        ],
      );
      addTearDown(container.dispose);
      container.read(readerModeProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await container.read(readerModeProvider.notifier).set(mode);
      final shown = <int?>[];
      container.listen(ayahModeTargetProvider, (_, id) => shown.add(id));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ReaderScreen(location: QuranLocation.surah(1)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(shown, contains(1001));
      // Closed: no longer asked.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(container.read(ayahModeTargetProvider), isNull);
    });
  }
}
