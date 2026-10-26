import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/core/ui/motion.dart';

/// The phone's "remove animations": Tahfeez's own animations settle at once.
void main() {
  Widget app(Widget child) => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('the loading placeholder stands still', (tester) async {
    await tester.pumpWidget(app(const TahfeezLoadingView()));
    // Would time out while it pulsed.
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezLoadingView), findsOneWidget);
  });

  testWidgets('motion() is none with animations off, as asked otherwise', (
    tester,
  ) async {
    late Duration off, on;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            off = motion(context, const Duration(seconds: 1));
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            on = motion(context, const Duration(seconds: 1));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(off, Duration.zero);
    expect(on, const Duration(seconds: 1));
  });
}
