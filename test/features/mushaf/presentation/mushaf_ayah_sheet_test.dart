import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_translations.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_ayah_sheet.dart';
import 'package:tahfeez_ai/quran/application/ayah_sheet_content.dart';
import 'package:tahfeez_ai/quran/application/canonical_ayah_word_text.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/application/tafsir_verse_text.dart';
import 'package:tahfeez_ai/quran/domain/models/tafsir_models.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';

import '../../../test_helpers/widget_test_overrides.dart';

void main() {
  const book = TranslationBook(
    slug: 'en-rowwad',
    displayName: 'Rowwad',
    languageCode: 'en',
    author: 'Rowwad Translation Center',
    version: 1,
    source: 'test',
    license: 'test',
    checksum: 'x',
  );

  Widget app(
    AyahSheetContent content, {
    String? tafsirId = 'ar-muyassar',
  }) => ProviderScope(
    overrides: [
      ...tahfeezWidgetTestOverrides(),
      ayahSheetContentProvider.overrideWithBuild((ref, _) => content),
      tafsirSelectionControllerProvider.overrideWithBuild((ref, _) => tafsirId),
      canonicalAyahTextProvider.overrideWith(
        (ref, _) async => 'قُلۡ هُوَ ٱللَّهُ أَحَدٌ',
      ),
      activeTranslationBooksProvider.overrideWith(
        (ref) async => {'en-rowwad': book},
      ),
      mushafPageTranslationsProvider.overrideWith(
        (ref, _) async => {
          112001: {
            'en-rowwad': const TranslationVerseText(
              slug: 'en-rowwad',
              chapterNo: 112,
              verseNo: 1,
              text: 'Say: He is Allah, the One.[1]',
              footnotes: [TranslationFootnote(marker: 1, text: 'He is Alone.')],
            ),
          },
        },
      ),
      tafsirVerseTextProvider.overrideWith(
        (ref, _) async => const TafsirVerseText(
          tafsirId: 'ar-muyassar',
          chapterNo: 112,
          verseNo: 1,
          text: 'قل -أيها الرسول-: هو الله المتفرد بالألوهية.',
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAyahDetailSheet(
            context,
            mushafId: 1,
            pageNumber: 604,
            ayahId: 112001,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('both: the translation, then the tafsir with Read more', (
    tester,
  ) async {
    await open(tester, app(AyahSheetContent.both));
    expect(find.textContaining('Say: He is Allah, the One.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ayah-sheet-tafsir-text')),
      findsOneWidget,
    );
    expect(find.text('Read more'), findsOneWidget);
    // The translator's note, listed under the translation.
    expect(find.byKey(const ValueKey('footnote-1')), findsOneWidget);
    expect(find.textContaining('He is Alone.'), findsOneWidget);
  });

  testWidgets('translation only, or tafsir only, as chosen in Settings', (
    tester,
  ) async {
    await open(tester, app(AyahSheetContent.translation));
    expect(find.textContaining('Say: He is Allah, the One.'), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-sheet-tafsir-text')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await open(tester, app(AyahSheetContent.tafsir));
    expect(find.textContaining('Say: He is Allah, the One.'), findsNothing);
    expect(
      find.byKey(const ValueKey('ayah-sheet-tafsir-text')),
      findsOneWidget,
    );
  });

  testWidgets('no tafsir chosen: where to choose one', (tester) async {
    await open(tester, app(AyahSheetContent.tafsir, tafsirId: null));
    expect(
      find.text(
        'No tafsir chosen. Choose one in Settings → Translation & tafsir.',
      ),
      findsOneWidget,
    );
  });
}
