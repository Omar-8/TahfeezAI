import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/ui/type_once.dart';

/// Revealed word by word the first time in a run (owner, 2026-11-21: each
/// word fading in), laid out whole from the start; whole at once after
/// that.
void main() {
  setUp(TypeOnce.reset);

  Widget app() => MaterialApp(
    home: TypeOnce(
      id: 'greeting',
      length: 18,
      builder: (context, typed) => Text.rich(
        TextSpan(
          children: revealedWordSpans(
            'Wa alaykum assalam',
            typed,
            Colors.black,
          ),
        ),
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
    // Every word laid out; the first ones shown (more than the last).
    expect(mid.map((s) => s.text).join(), 'Wa alaykum assalam');
    expect(mid, hasLength(3));
    final alphas = [for (final s in mid) s.style!.color!.a];
    expect(alphas.first, greaterThan(alphas.last), reason: 'in order');
    expect(alphas.last, lessThan(1), reason: 'the last not yet whole');
    await tester.pumpAndSettle();
    expect(spans(tester).single.text, 'Wa alaykum assalam');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(
      spans(tester).single.text,
      'Wa alaykum assalam',
      reason: 'already revealed',
    );
  });

  testWidgets('"remove animations" on: whole at once', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(),
      ),
    );
    expect(spans(tester).single.text, 'Wa alaykum assalam');
  });
}
