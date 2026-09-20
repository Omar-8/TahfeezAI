// Exercises TahfeezBootstrapGate in isolation (a bare Completer standing
// in for the real BundledDatasetSeeder.seedIfNeeded() future -- this is a
// widget-level contract test, not a re-test of seeding itself): it must
// show a loading state while the seeding future is pending, and hand off
// to the real app the instant it resolves, never before.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/bootstrap_gate.dart';

import '../test_helpers/widget_test_overrides.dart';

void main() {
  Widget gate(Future<void> seeding) => ProviderScope(
    overrides: tahfeezWidgetTestOverrides(),
    child: TahfeezBootstrapGate(seeding: seeding),
  );

  testWidgets(
    'shows a loading indicator while seeding is pending, then swaps to '
    'the real app once it resolves',
    (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(gate(completer.future));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('never builds the real app before seeding completes', (
    tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(gate(completer.future));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
