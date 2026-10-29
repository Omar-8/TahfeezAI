// A sheet's last row (SheetActions): Cancel — or the button in its place —
// only as wide as its word and never wider than 40% of the row, the main
// button filling the rest to the row's end; Cancel closes the sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/fallback_localizations.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/ui/sheet_actions.dart';

void main() {
  const primaryKey = ValueKey('primary');
  const rowKey = ValueKey('row');

  Widget sheetApp({
    Widget? secondary,
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      ...kFallbackLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => MediaQuery.withClampedTextScaling(
                minScaleFactor: textScale,
                maxScaleFactor: textScale,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SheetActions(
                    key: rowKey,
                    secondary: secondary,
                    primary: FilledButton(
                      key: primaryKey,
                      onPressed: () {},
                      child: const Text('Start'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void expectLaidOut(WidgetTester tester, Finder first) {
    expect(tester.takeException(), isNull, reason: 'no overflow');
    final row = tester.getRect(find.byKey(rowKey));
    final cancel = tester.getRect(first);
    final primary = tester.getRect(find.byKey(primaryKey));
    expect(cancel.width, lessThanOrEqualTo(row.width * 0.4 + 0.5));
    expect(cancel.width, lessThan(primary.width));
    // To the row's end: its right edge, or its left in a right-to-left
    // language (the row mirrored, Cancel first on the right).
    final rtl = Directionality.of(tester.element(first)) == TextDirection.rtl;
    expect(
      rtl ? primary.left : primary.right,
      moreOrLessEquals(rtl ? row.left : row.right),
      reason: 'to the end',
    );
  }

  for (final (scale, locale) in [
    (1.0, const Locale('en')),
    (2.0, const Locale('en')),
    (2.0, const Locale('ckb')),
    (1.0, const Locale('ar')),
  ]) {
    testWidgets('Cancel narrower, the main button to the end: '
        '${locale.languageCode} at ${scale}x', (tester) async {
      await open(tester, sheetApp(textScale: scale, locale: locale));
      expectLaidOut(tester, find.byKey(SheetActions.cancelKey));
    });
  }

  testWidgets('a button in Cancel\'s place, laid out the same', (tester) async {
    const stop = ValueKey('stop');
    await open(
      tester,
      sheetApp(
        secondary: TextButton(
          key: stop,
          onPressed: () {},
          child: SheetActions.label('Stop plan'),
        ),
      ),
    );
    expect(find.byKey(SheetActions.cancelKey), findsNothing);
    expectLaidOut(tester, find.byKey(stop));
  });

  testWidgets('Cancel closes the sheet', (tester) async {
    await open(tester, sheetApp());
    await tester.tap(find.byKey(SheetActions.cancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(rowKey), findsNothing);
  });
}
