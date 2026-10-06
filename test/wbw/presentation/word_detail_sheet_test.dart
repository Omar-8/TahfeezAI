import 'package:drift/native.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/application/canonical_ayah_word_text.dart';
import 'package:tahfeez_ai/wbw/application/wbw_preferences_controller.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/presentation/word_detail_sheet.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import '../wbw_test_fixtures.dart';

void main() {
  Widget wrap(WbwDatabase db, {String? selectedPackId}) {
    return ProviderScope(
      overrides: [
        wbwDatabaseProvider.overrideWith((ref) => db),
        canonicalAyahWordTextProvider(
          ayahId: 1001,
          wordIndex: 0,
        ).overrideWith((ref) => 'lafz'),
        if (selectedPackId != null)
          wbwSelectedPackControllerProvider.overrideWith(
            () => _FixedSelectedPack(selectedPackId),
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWordDetailSheet(
                context,
                wordRef: (ayahId: 1001, wordIndex: 0),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('always shows the Arabic word and its location', (tester) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('lafz'), findsOneWidget);
    expect(find.textContaining('Ayah 1:1'), findsOneWidget);
  });

  testWidgets('shows an install hint with no active word-by-word pack', (
    tester,
  ) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Install a word-by-word language pack'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows translation and transliteration once a pack is installed and active',
    (tester) async {
      final db = WbwDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [wbwDatabaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      await container
          .read(wbwRepositoryProvider)
          .installPack(buildTestWbwPack(), buildTestWbwWords());

      await tester.pumpWidget(wrap(db, selectedPackId: testWbwPackId));
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('word'), findsOneWidget);
      expect(
        find.text('lafz'),
        findsWidgets,
      ); // both the tapped word + transliteration
    },
  );
}

class _FixedSelectedPack extends WbwSelectedPackController {
  _FixedSelectedPack(this._fixed);

  final String _fixed;

  @override
  String? build() => _fixed;
}
