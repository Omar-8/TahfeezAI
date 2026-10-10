import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_controller.dart';
import 'package:tahfeez_ai/features/listen/presentation/listen_sheet.dart';

void main() {
  testWidgets('typing finds a reciter by English or Arabic name', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReciterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('reciter-search'));

    await tester.enterText(search, 'husary');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reciter-ar.husary')), findsOneWidget);
    expect(find.byKey(const ValueKey('reciter-ar.alafasy')), findsNothing);

    // Arabic, without the vowel marks the name is written with.
    await tester.enterText(search, 'المنشاوي');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reciter-ar.minshawi')), findsOneWidget);
    expect(find.byKey(const ValueKey('reciter-ar.husary')), findsNothing);

    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No reciter by that name'), findsOneWidget);

    await tester.enterText(search, 'alafasy');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reciter-ar.alafasy')));
    await tester.pumpAndSettle();
    expect(container.read(reciterProvider), 'ar.alafasy');
  });
}
