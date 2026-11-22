import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/quran_mark.dart';

/// The Quran tab's mark: every few seconds a pulse — a green glow that
/// swells and fades, a green ring spreading out from it (owner,
/// 2026-11-20) — still between, none with animations off.
void main() {
  Widget host({bool still = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: const Center(child: QuranMark(size: 48, selected: true)),
    ),
  );

  List<BoxShadow> glow(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('quran-mark-glow')),
                  )
                  .decoration
              as BoxDecoration)
          .boxShadow!;

  /// The ring drawn: the pulse under way.
  bool ring(WidgetTester tester) {
    final t =
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('quran-mark-pulse')),
                    )
                    .painter!
                as QuranMarkRing)
            .t;
    return t > 0 && t < 1;
  }

  testWidgets('pulses now and then, green, a ring spreading; rests between', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(glow(tester), isEmpty, reason: 'at rest as it appears');
    expect(ring(tester), isFalse);
    await tester.pump(QuranMark.glowFirst);
    await tester.pump(QuranMark.glowLength * 0.2);
    final early = glow(tester).single;
    expect(ring(tester), isTrue);
    await tester.pump(QuranMark.glowLength * 0.3);
    final height = glow(tester).single;
    expect(height.blurRadius, greaterThan(early.blurRadius));
    // Light mode: Home's "AI" green (owner, 2026-11-20).
    final green = QuranMark.greenOf(tester.element(find.byType(QuranMark)));
    expect(height.color.withValues(alpha: 1), green.withValues(alpha: 1));
    // Over: at rest — the screen settles.
    await tester.pumpAndSettle();
    expect(glow(tester), isEmpty);
    expect(ring(tester), isFalse);
    // …and again after a while.
    var again = false;
    for (var ms = 0; ms < QuranMark.glowEvery.inMilliseconds; ms += 100) {
      await tester.pump(const Duration(milliseconds: 100));
      again |= glow(tester).isNotEmpty && ring(tester);
    }
    expect(again, isTrue, reason: 'within ${QuranMark.glowEvery}');
    await tester.pumpAndSettle();
    // Gone: its timer with it (the test would fail on a pending timer).
    await tester.pumpWidget(const SizedBox());
  });

  QuranMarkRing painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('quran-mark-pulse')),
              )
              .painter!
          as QuranMarkRing;

  testWidgets('in the app: its arc going round and round, without end', (
    tester,
  ) async {
    QuranMark.spinning = true;
    addTearDown(() => QuranMark.spinning = false);
    await tester.pumpWidget(host());
    var last = painter(tester).spin;
    for (var i = 0; i < 12; i++) {
      await tester.pump(QuranMark.spinRound * 0.3);
      final now = painter(tester);
      expect(now.spinning, isTrue);
      expect(now.spin, isNot(last), reason: 'moving ($i)');
      last = now.spin;
    }
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with animations off: no pulse', (tester) async {
    QuranMark.spinning = true;
    addTearDown(() => QuranMark.spinning = false);
    await tester.pumpWidget(host(still: true));
    await tester.pump(QuranMark.glowFirst + QuranMark.glowLength * 0.5);
    expect(glow(tester), isEmpty);
    expect(ring(tester), isFalse);
    await tester.pump(QuranMark.glowEvery * 2);
    expect(glow(tester), isEmpty);
    expect(painter(tester).spinning, isFalse, reason: 'no arc going round');
  });
}
