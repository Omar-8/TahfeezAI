import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/tahfeez_bottom_sheet.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';

import '../../test_helpers/real_app.dart';

/// Hifz settings searched by a word, as Settings is (owner, 2026-11-16):
/// both tabs' settings found in one list — Advanced's too, whatever the
/// level — their groups opened and the words found highlighted.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  testWidgets('a word finds the settings of both tabs; nothing found said', (
    tester,
  ) async {
    await RealApp.launch(tester, route: '/quran/surah/112');
    showHifzSettingsSheet(tester.element(find.byType(Scaffold).last));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('hifz-settings-search'));
    expect(search, findsOneWidget);
    expect(find.byKey(const ValueKey('hifz-settings-tabs')), findsOneWidget);
    // A level chosen: Advanced's groups not shown.
    expect(find.text('Sujood al-Tilawah reminder'), findsNothing);
    final top = tester.getTopLeft(search).dy;

    // In a group of Advanced's (Other), found and highlighted.
    await tester.enterText(search, 'sujood');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hifz-settings-tabs')), findsNothing);
    expect(find.text('Sujood al-Tilawah reminder'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-search-match')), findsWidgets);
    expect(find.text('Mistake hints while reciting'), findsNothing);
    expect(find.byKey(const ValueKey('mushaf-page-theme')), findsNothing);

    // Another group's (Marks).
    await tester.enterText(search, 'mistake hints');
    await tester.pumpAndSettle();
    expect(find.text('Mistake hints while reciting'), findsOneWidget);
    expect(find.text('Sujood al-Tilawah reminder'), findsNothing);

    // The appearance tab's: the page's theme.
    await tester.enterText(search, 'page theme');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mushaf-page-theme')), findsOneWidget);
    expect(find.byKey(const ValueKey('mushaf-passages')), findsNothing);

    // Nothing.
    await tester.enterText(search, 'zzqq');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hifz-settings-no-match')),
      findsOneWidget,
    );
    // The sheet as tall as with its tabs, however little was found.
    expect(tester.getTopLeft(search).dy, top);

    // The keyboard up (owner, 2026-11-17): the page and its bar not
    // squeezed above it; the sheet lifted over it, as tall as before.
    final pageHeights = [
      for (final s in find.byType(Scaffold).evaluate())
        (s.renderObject! as RenderBox).size.height,
    ];
    final sheetHeight = tester.getSize(find.byType(GlassSheet).last).height;
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect([
      for (final s in find.byType(Scaffold).evaluate())
        (s.renderObject! as RenderBox).size.height,
    ], pageHeights);
    expect(tester.getSize(find.byType(GlassSheet).last).height, sheetHeight);
    expect(
      tester.getBottomLeft(find.byType(GlassSheet).last).dy,
      tester.view.physicalSize.height / tester.view.devicePixelRatio - 300,
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    // Cleared: the tabs again.
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hifz-settings-tabs')), findsOneWidget);

    // Advanced: each group closed, what it is set to under its title
    // (owner, 2026-11-17).
    final advanced = find.byKey(const ValueKey('hifz-level-advanced'));
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.text('Sujood al-Tilawah reminder: On'), findsOneWidget);

    await RealApp.quit(tester);
  });
}
