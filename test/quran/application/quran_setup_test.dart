import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/app_store/app_store_service.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/quran/application/quran_setup.dart';
import 'package:tahfeez_ai/quran/presentation/quran_unavailable_view.dart';

void main() {
  test(
    'a failed setup is kept; trying again clears it once it works',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      var attempts = 0;
      await c
          .read(quranSetupProvider.notifier)
          .run(
            () async => ++attempts == 1
                ? 'SqliteException(13): database or disk is full'
                : null,
          );
      expect(c.read(quranSetupProvider).failure, contains('disk is full'));
      expect(c.read(quranSetupProvider).storageFull, isTrue);

      await c.read(quranSetupProvider.notifier).retry();
      expect(attempts, 2);
      expect(c.read(quranSetupProvider).failure, isNull);
    },
  );

  test('a setup that throws is kept as its failure', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(quranSetupProvider.notifier)
        .run(() async => throw StateError('Out of Memory'));
    expect(c.read(quranSetupProvider).failure, contains('Out of Memory'));
    expect(c.read(quranSetupProvider).storageFull, isFalse);
  });

  test('the report names the version, the device and the error', () {
    final report = quranSetupReport('boom', version: '1.0.0');
    expect(report, contains('1.0.0'));
    expect(report, contains('boom'));
    expect(report.split('\n'), hasLength(3));
  });

  Future<ProviderContainer> pumpView(
    WidgetTester tester,
    String? failure,
  ) async {
    final c = ProviderContainer(
      overrides: [appVersionProvider.overrideWith((ref) async => '1.0.0')],
    );
    addTearDown(c.dispose);
    await c.read(quranSetupProvider.notifier).run(() async => failure);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: QuranUnavailableView()),
        ),
      ),
    );
    await tester.pump();
    return c;
  }

  testWidgets('a failure stays on screen, with its error and the buttons', (
    tester,
  ) async {
    await pumpView(tester, 'Could not load assets/quran/quran_dataset.json');
    expect(
      find.text("The Quran couldn't be set up on this phone."),
      findsOneWidget,
    );
    expect(
      find.text('Could not load assets/quran/quran_dataset.json'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Share details'), findsOneWidget);
    // Still there long after: nothing fades it away.
    await tester.pump(const Duration(minutes: 5));
    expect(
      find.text('Could not load assets/quran/quran_dataset.json'),
      findsOneWidget,
    );
  });

  testWidgets('a full phone is told to free some space', (tester) async {
    await pumpView(tester, 'SqliteException(13): database or disk is full');
    expect(find.textContaining('storage is full'), findsOneWidget);
  });

  testWidgets('without a failure: the plain message, no buttons', (
    tester,
  ) async {
    await pumpView(tester, null);
    expect(find.byKey(const ValueKey('quran-setup-failed')), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });
}
