import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';

import '../test_helpers/real_app.dart';

/// The reader's title names the surah opened — Ya-Sin, on page 440 that
/// starts with Faatir's end — in either mode; a page opened as a page is
/// titled by the surah it starts with.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  Finder title(String name) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(name));

  for (final mode in ReaderMode.values) {
    testWidgets('${mode.name}: Ya-Sin opened, Ya-Sin in the title', (
      tester,
    ) async {
      await RealApp.launch(tester, route: '/quran/surah/36', mode: mode);
      expect(title('Yaseen'), findsOneWidget);
      expect(title('Faatir'), findsNothing);
      await RealApp.quit(tester);
    });
  }

  testWidgets('page 440 opened as a page: titled by the surah it starts '
      'with', (tester) async {
    final container = await RealApp.launch(tester);
    final mushaf = (await tester.runAsync(
      () => container.read(defaultMushafProvider.future),
    ))!;
    container.read(appRouterProvider).go('/quran/page/${mushaf.id}/440');
    await RealApp.settle(tester);
    expect(title('Faatir'), findsOneWidget);
    await RealApp.quit(tester);
  });

  testWidgets('Ayah mode: scrolled from Al-Ikhlas into the next surahs on '
      'the page, the title follows', (tester) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/112',
      mode: ReaderMode.ayah,
    );
    expect(title('Al-Ikhlaas'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -600),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
    await RealApp.settle(tester);
    expect(title('Al-Ikhlaas'), findsNothing);
    expect(
      title('Al-Falaq').evaluate().isNotEmpty ||
          title('An-Naas').evaluate().isNotEmpty,
      isTrue,
    );
    await RealApp.quit(tester);
  });
}
