import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/ui/back_to_exit.dart';

import '../test_helpers/widget_test_overrides.dart';

/// On every tab's first screen: back once to be told, twice to leave.
void main() {
  for (final route in const ['/home', '/quran', '/memorize', '/settings']) {
    testWidgets('$route: back once tells, twice leaves the app', (
      tester,
    ) async {
      resetBackToExit();
      var left = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') left++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...tahfeezWidgetTestOverrides()],
          child: const TahfeezApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = ProviderScope.containerOf(
        tester.element(find.byType(TahfeezApp)),
      ).read(appRouterProvider);
      router.go(route);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(left, 0);
      expect(router.state.uri.path, route, reason: 'still here');

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(left, 1);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  }
}
