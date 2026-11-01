import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';

import '../test_helpers/real_app.dart';

/// About a surah: tapping its name at its start (Ayah mode), or "About this
/// surah" in Go to — its facts from the bundled data, then Read.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  Finder fact(String label, String value) => find.ancestor(
    of: find.text(value),
    matching: find.ancestor(of: find.text(label), matching: find.byType(Row)),
  );

  testWidgets('As-Sajdah\'s name tapped in Ayah mode: Meccan, 30 ayahs, its '
      'sajdah at ayah 15, juz 21', (tester) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/32',
      mode: ReaderMode.ayah,
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-32')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-32')), findsOneWidget);
    expect(fact('Revealed in', 'Meccan'), findsOneWidget);
    expect(fact('Order of revelation', '75'), findsOneWidget);
    expect(fact('Ayahs', '30'), findsOneWidget);
    expect(fact('Sajdah', 'Ayah 15'), findsOneWidget);
    expect(fact('Juz', '21'), findsOneWidget);
    expect(find.text('The Prostration'), findsOneWidget, reason: 'its meaning');
    await RealApp.quit(tester);
  });

  testWidgets('from Go to: the chosen surah\'s facts; Read opens it', (
    tester,
  ) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/1',
      mode: ReaderMode.ayah,
    );
    // The title opens Go to; its surah is the one read.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Al-Faatiha'),
      ),
    );
    await RealApp.settle(tester);
    await tester.tap(find.byKey(const ValueKey('jump-surah-info')));
    await RealApp.settle(tester);
    expect(fact('Ayahs', '7'), findsOneWidget);
    expect(find.byKey(const ValueKey('surah-info-sajdah')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('surah-info-read')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-1')), findsNothing);
    await RealApp.quit(tester);
  });
}
