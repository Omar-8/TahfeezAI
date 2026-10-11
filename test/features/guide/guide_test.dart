import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/guide/guide.dart';

void main() {
  late ProviderContainer container;
  var followTaps = 0, reciteTaps = 0;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    followTaps = 0;
    reciteTaps = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => GuideLayer(child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: GuideTarget(
                id: 'bar',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GuideTarget(
                      id: 'mode-recite',
                      child: TextButton(
                        onPressed: () => reciteTaps++,
                        child: const Text('recite'),
                      ),
                    ),
                    GuideTarget(
                      id: 'mode-follow',
                      child: TextButton(
                        onPressed: () => followTaps++,
                        child: const Text('follow'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  GuideState? guide() => container.read(guideProvider);

  testWidgets('steps on with Next and back with Back; closes at any step', (
    tester,
  ) async {
    await pump(tester);
    container.read(guideProvider.notifier).start();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-card')), findsOneWidget);
    expect(find.text('1/8'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guide-next')));
    await tester.pumpAndSettle();
    expect(guide()!.index, 1);
    await tester.tap(find.byKey(const ValueKey('guide-back')));
    await tester.pumpAndSettle();
    expect(guide()!.index, 0);

    // A step that only explains: taps on the control don't reach it.
    container.read(guideProvider.notifier).next();
    await tester.pumpAndSettle();
    await tester.tap(find.text('recite'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(reciteTaps, 0);

    await tester.tap(find.byKey(const ValueKey('guide-close')));
    await tester.pumpAndSettle();
    expect(guide(), isNull);
    expect(find.byKey(const ValueKey('guide-card')), findsNothing);
  });

  testWidgets('choosing a mode at the end goes through to it and into its '
      'tour', (tester) async {
    await pump(tester);
    container.read(guideProvider.notifier).start(GuideTour.overview, 7);
    await tester.pumpAndSettle();
    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();
    expect(followTaps, 1, reason: 'the tap reached the button');
    expect(guide(), (tour: GuideTour.follow, index: 1));
  });

  test('finishing a mode tour goes back to choosing a mode', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final guide = c.read(guideProvider.notifier);
    guide.start(GuideTour.follow, guideSteps(GuideTour.follow).length - 1);
    guide.next();
    expect(c.read(guideProvider), (
      tour: GuideTour.overview,
      index: guideSteps(GuideTour.overview).length - 1,
    ));
    guide.next(); // Done on the choice: the guide ends.
    expect(c.read(guideProvider), isNull);
  });

  test('the eye, chosen, opens the hide-and-reveal tour', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final guide = c.read(guideProvider.notifier);
    guide.start(GuideTour.overview, guideSteps(GuideTour.overview).length - 1);
    guide.tapped('eye');
    expect(c.read(guideProvider), (tour: GuideTour.hide, index: 1));
  });
}
