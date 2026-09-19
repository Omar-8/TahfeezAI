import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/app_routes.dart';
import 'package:tahfeez_ai/core/routing/quran_location_routing.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  testWidgets(
    'tapping the Mushaf mode segment navigates to the real Mushaf reader at the current position',
    (tester) async {
      final db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      addTearDown(db.close);

      // `goToQuranLocation` always builds paths under `AppRoutes.quran`
      // (matching the real app's route tree in `app_router.dart`), so the
      // test router must mount `quranLocationRoutes()` there too, not at
      // an arbitrary path -- otherwise the resulting `go()` call matches
      // no registered route in this test's own router.
      final router = GoRouter(
        initialLocation: AppRoutes.quran,
        routes: [
          GoRoute(
            path: AppRoutes.quran,
            builder: (context, state) =>
                const ReaderScreen(location: QuranLocation.surah(1)),
            routes: quranLocationRoutes(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quranDatabaseProvider.overrideWith((ref) => db),
            quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mushaf'));
      // `_switchToMushaf` awaits two repository queries before navigating;
      // give those async gaps a chance to resolve before settling on the
      // resulting frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Surah 1's ayahs (1001-1007) are all on the fixture's page 1, so the
      // Mushaf reader should open there.
      expect(find.text('Mushaf'), findsOneWidget);
      expect(find.textContaining('Page 1'), findsWidgets);
    },
  );
}
