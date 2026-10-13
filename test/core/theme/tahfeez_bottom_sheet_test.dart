import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/tahfeez_bottom_sheet.dart';

void main() {
  testWidgets('a tall sheet from a tab screen stays below its app bar and '
      'over the shell bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
    // A shell: the tab's own navigator above a bottom bar, its screen with
    // a tall app bar.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      toolbarHeight: 72,
                      title: const Text('Page'),
                      actions: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.repeat),
                            onPressed: () => showTahfeezModalBottomSheet<void>(
                              context: context,
                              builder: (_) => const SingleChildScrollView(
                                child: SizedBox(height: 2000),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 90, child: Text('shell bar')),
          ],
        ),
      ),
    );
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(tester.getTopLeft(sheet).dy, closeTo(appBarBottom, 0.5));
    expect(tester.getBottomLeft(sheet).dy, 800, reason: 'over the shell bar');
  });

  testWidgets('with the keyboard up, the sheet is lifted above it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTahfeezModalBottomSheet<void>(
                context: context,
                title: 'Go to ayah',
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TextField(key: Key('field')),
                    FilledButton(onPressed: () {}, child: const Text('Go')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Go')).dy, lessThanOrEqualTo(500));
    expect(
      tester.getTopLeft(find.byKey(const Key('field'))).dy,
      greaterThan(0),
    );
  });
}
