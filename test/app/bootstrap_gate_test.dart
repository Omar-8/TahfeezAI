// Exercises TahfeezBootstrapGate in isolation (a bare Completer standing
// in for the real BundledDatasetSeeder.seedIfNeeded() future -- this is a
// widget-level contract test, not a re-test of seeding itself): it must
// show the splash (the app's name) while the seeding future is pending,
// and hand off to the real app once it resolves, never before.
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
    'shows the splash while seeding is pending, then swaps to the real app '
    'once it resolves',
    (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(gate(completer.future));
      await tester.pump();

      expect(find.text('TahfeezAI'), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing);

      completer.complete();
      // (The splash shows at least 0.9 s.)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );

  testWidgets('never builds the real app before seeding completes', (
    tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(gate(completer.future));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
