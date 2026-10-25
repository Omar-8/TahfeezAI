import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/presentation/surah_name_calligraphy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 114 names load, each a real outline', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final names = await c.read(surahNameArtProvider.future);
    expect(names.keys.toSet(), {for (var s = 1; s <= 114; s++) s});
    for (final art in names.values) {
      final b = art.path.getBounds();
      expect(b.width, greaterThan(art.size.width * 0.8));
      expect(b.height, greaterThan(art.size.height * 0.5));
    }
  });

  testWidgets('drawn at the height asked, labelled with its name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Center(
            child: SurahNameCalligraphy(surahNo: 112, semanticLabel: 'الإخلاص'),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    final box = tester.getSize(find.byType(SurahNameCalligraphy));
    expect(box.height, 28);
    expect(box.width, inInclusiveRange(30, 110));
    expect(find.bySemanticsLabel('الإخلاص'), findsOneWidget);
  });
}
