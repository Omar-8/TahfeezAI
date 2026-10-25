import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/guide/guide.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';

void main() {
  late ProviderContainer container;
  final results = <bool>[];

  Future<void> pump(WidgetTester tester) async {
    // Nothing saved by a test before.
    await tester.runAsync(
      () => SharedPreferencesAsync().remove(HifzSettingsController.storageKey),
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
    results.clear();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  for (final mode in RecitationIntroMode.values)
                    TextButton(
                      onPressed: () async =>
                          results.add(await showRecitationIntro(context, mode)),
                      child: Text(mode.name),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder sheet() => find.byKey(const ValueKey('recitation-intro'));

  Future<void> start(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('recitation-intro-start'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('outside the guide: once, for whichever mode comes first', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('loop'));
    await tester.pumpAndSettle();
    expect(sheet(), findsOneWidget);
    await start(tester);
    expect(results, [true]);
    // Not again — for this mode or the others.
    for (final mode in ['loop', 'recite', 'follow']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing, reason: mode);
    }
    expect(results, [true, true, true, true]);
  });

  testWidgets('in the guide: each time, and not counted as seen', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < 2; i++) {
      container.read(guideProvider.notifier).start(GuideTour.recite, 3);
      await tester.tap(find.text('recite'));
      await tester.pumpAndSettle();
      expect(sheet(), findsOneWidget, reason: 'guide run ${i + 1}');
      await start(tester);
      container.read(guideProvider.notifier).close();
    }
    expect(container.read(hifzSettingsProvider).introsSeen, isEmpty);
    // A reader who then recites outside the guide still gets it once.
    await tester.tap(find.text('recite'));
    await tester.pumpAndSettle();
    expect(sheet(), findsOneWidget);
  });
}
