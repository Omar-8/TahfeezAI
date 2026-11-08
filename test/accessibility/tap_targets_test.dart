import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/theme/components/tahfeez_collapsible_section.dart';

import '../test_helpers/widget_test_overrides.dart';

/// Every tappable on the main screens at least 48 × 48 (Android's
/// guideline; iOS asks 44): a phone in portrait.
void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets("Qur'an", (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.text("Qur'an"));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('Settings', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('Settings, every group opened', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // Tall enough for all of it on screen at once.
    tester.view.physicalSize = const Size(390, 5000);
    await tester.pumpAndSettle();
    final sections = find.byType(TahfeezCollapsibleSection);
    for (var i = 0; i < sections.evaluate().length; i++) {
      await tester.tap(
        find
            .descendant(of: sections.at(i), matching: find.byType(InkWell))
            .first,
      );
      await tester.pumpAndSettle();
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
