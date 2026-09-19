import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/multi_script_test_fixtures.dart';

/// End-to-end proof of Milestone 8's "scripts are swappable without UI
/// rewrites" requirement: `ReaderScreen` never branches on which script is
/// active — picking a different one from the Reader options sheet's Quran
/// script picker is enough, on its own, to change the rendered word text.
void main() {
  testWidgets(
    'picking a different script from the options sheet changes the rendered words',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await const QuranDatasetImporter().import(
        db,
        buildMultiScriptSyntheticPayload(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [quranDatabaseProvider.overrideWith((ref) => db)],
          child: const MaterialApp(
            supportedLocales: [Locale('en'), Locale('ar')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ReaderScreen(location: QuranLocation.surah(1)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No preference selected yet defaults to `defaultQuranScriptCode`,
      // which matches neither fixture script — pick Script A first to
      // establish a known baseline. "Quran script" opens a second sheet
      // stacked on top of "Reader options" (it does not replace it), so
      // both must be dismissed before interacting with the screen again.
      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quran script'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Script A'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss the script sheet
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss reader options
      await tester.pumpAndSettle();

      expect(find.text('lafz'), findsWidgets);
      expect(find.text('harf'), findsNothing);

      // Switching to Script B — no code change to `ReaderScreen` itself —
      // changes the rendered word text.
      await tester.tap(find.byTooltip('Reader options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quran script'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Script B'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss the script sheet
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss reader options
      await tester.pumpAndSettle();

      expect(find.text('harf'), findsWidgets);
      expect(find.text('lafz'), findsNothing);
    },
  );
}
