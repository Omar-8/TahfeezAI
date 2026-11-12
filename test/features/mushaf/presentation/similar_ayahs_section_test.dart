import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/similar_ayahs_section.dart';
import 'package:tahfeez_ai/quran/application/similar_ayahs_provider.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/similar_ayahs.dart';

import '../../../test_helpers/widget_test_overrides.dart';

/// The ayah sheet's similar ayahs: how many, the first three then all,
/// each in its words with those it does not share marked; none, nothing.
void main() {
  const words = ['وَلَا', 'يُقْبَلُ', 'مِنْهَا', 'عَدْلٌ'];
  SimilarAyah like(int id, {Set<int> differ = const {3}, int score = 80}) =>
      SimilarAyah(ayahId: id, score: score, differ: differ, otherDiffer: {});

  Widget app(List<SimilarAyah> similar) => ProviderScope(
    overrides: [
      ...tahfeezWidgetTestOverrides(),
      ayahLookAlikesProvider.overrideWith((ref, _) => similar),
      ayahCanonicalWordsProvider.overrideWith(
        (ref, ayahId) async => [
          for (var i = 0; i < words.length; i++)
            AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: i, text: words[i]),
        ],
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: SimilarAyahsSection(ayahId: 2048)),
      ),
    ),
  );

  testWidgets('the first three, then all; the differing words marked', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([like(2123), like(2254, score: 70), like(3091), like(7161)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Similar ayahs · 4'), findsOne);
    expect(find.byKey(const ValueKey('similar-ayah-2123')), findsOne);
    expect(find.byKey(const ValueKey('similar-ayah-7161')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('similar-ayahs-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('similar-ayah-7161')), findsOne);
    expect(find.byKey(const ValueKey('similar-ayahs-all')), findsNothing);

    final text = tester.widget<Text>(
      find.byKey(const ValueKey('similar-ayah-text-2123')),
    );
    final spans = [
      for (final s in (text.textSpan! as TextSpan).children!.cast<TextSpan>())
        if (s.text != ' ') s,
    ];
    expect([for (final s in spans) s.text], words);
    expect(spans[3].style?.fontWeight, FontWeight.w700, reason: 'differs');
    expect(spans[0].style, isNull, reason: 'shared');
  });

  testWidgets('a repeated ayah: "Same words"', (tester) async {
    await tester.pumpWidget(app([like(55016, differ: {}, score: 100)]));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('similar-ayah-same-55016')), findsOne);
  });

  testWidgets('no look-alikes: nothing shown', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('similar-ayahs')), findsNothing);
  });
}
