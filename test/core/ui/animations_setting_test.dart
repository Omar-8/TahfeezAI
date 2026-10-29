import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahfeez_ai/core/ui/animations_setting.dart';
import 'package:tahfeez_ai/core/ui/motion.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('turned off, the app animates as with "remove animations"', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    late Duration seen;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          builder: (context, child) => AnimationsOff(child: child!),
          home: Builder(
            builder: (context) {
              seen = motion(context, const Duration(milliseconds: 300));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen, const Duration(milliseconds: 300));

    await c.read(animationsProvider.notifier).setEnabled(false);
    await tester.pump();
    expect(seen, Duration.zero);

    await c.read(animationsProvider.notifier).setEnabled(true);
    await tester.pump();
    expect(seen, const Duration(milliseconds: 300));
  });
}
