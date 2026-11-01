import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/ui/type_once.dart';

/// Typed out the first time in a run, laid out whole from the start (the
/// rest transparent); whole at once after that.
void main() {
  setUp(TypeOnce.reset);

  Widget app() => MaterialApp(
    home: TypeOnce(
      id: 'greeting',
      length: 10,
      builder: (context, typed) => Text.rich(
        TextSpan(children: typedSpans('Assalamu..', typed)),
        key: const ValueKey('typed'),
      ),
    ),
  );

  List<TextSpan> spans(WidgetTester tester) =>
      ((tester.widget<Text>(find.byKey(const ValueKey('typed'))).textSpan!
                      as TextSpan)
                  .children ??
              const [])
          .cast<TextSpan>();

  testWidgets('typed once: partly shown mid-way, whole at the end; whole '
      'at once the next time', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16)); // its first frame
    await tester.pump(const Duration(milliseconds: 90));
    final mid = spans(tester);
    expect(mid, hasLength(2));
    expect(mid.first.text!.length, inInclusiveRange(1, 9));
    expect(mid.last.style?.color, Colors.transparent);
    expect(
      mid.first.text! + mid.last.text!,
      'Assalamu..',
      reason: 'laid out whole',
    );
    await tester.pumpAndSettle();
    expect(spans(tester).single.text, 'Assalamu..');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(spans(tester).single.text, 'Assalamu..', reason: 'already typed');
  });

  testWidgets('"remove animations" on: whole at once', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(),
      ),
    );
    expect(spans(tester).single.text, 'Assalamu..');
  });
}
