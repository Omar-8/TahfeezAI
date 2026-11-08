import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';

import '../../test_helpers/widget_test_overrides.dart';

void main() {
  for (final q in ['reciter', 'reset', 'theme', 'a']) {
    testWidgets('search "$q", keyboard closed: the field taps again', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          overrides: tahfeezWidgetTestOverrides(),
          child: const TahfeezApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('settings-search'));
      await tester.tap(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(search, q);
      await tester.pumpAndSettle();
      // The keyboard closed (its own button: the field keeps focus).
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsOneWidget);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
    });
  }
}
