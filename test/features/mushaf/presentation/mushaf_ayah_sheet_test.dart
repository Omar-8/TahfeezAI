import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_translations.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_ayah_sheet.dart';
import 'package:tahfeez_ai/quran/application/ayah_reading_extras.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/application/tafsir_verse_text.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
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
  const words = ['قُلۡ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'];

  Widget app({
    AyahViewPreferences view = const AyahViewPreferences(
      showTranslation: true,
      showTafsir: true,
    ),
    String? tafsirId = 'ar-muyassar',
  }) => ProviderScope(
    overrides: [
      ...tahfeezWidgetTestOverrides(),
      ayahViewPreferencesProvider.overrideWithBuild((ref, _) => view),
      tafsirSelectionControllerProvider.overrideWithBuild((ref, _) => tafsirId),
      ayahCanonicalWordsProvider.overrideWith(
        (ref, ayahId) async => [
          for (var i = 0; i < words.length; i++)
            AyahWord(
              ayahId: ayahId,
              scriptId: 1,
              wordIndex: i + 1,
              text: words[i],
            ),
        ],
      ),
      ayahWordMeaningsProvider.overrideWith(
        (ref, _) async => const {1: 'Say', 2: 'He', 3: 'Allah', 4: 'One'},
      ),
      ayahTransliterationProvider.overrideWith(
        (ref, _) async => 'qul huwa allahu ahadun',
      ),
      activeTranslationBooksProvider.overrideWith(
        (ref) async => {'en-rowwad': book},
      ),
      ayahTranslationsProvider.overrideWith(
        (ref, _) async => {
          'en-rowwad': const TranslationVerseText(
            slug: 'en-rowwad',
            chapterNo: 112,
            verseNo: 1,
            text: 'Say: He is Allah, the One.[1]',
            footnotes: [TranslationFootnote(marker: 1, text: 'He is Alone.')],
          ),
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
          onPressed: () => showAyahDetailSheet(context, ayahId: 112001),
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

  testWidgets('as Ayah mode shows it: words, translation, tafsir', (
    tester,
  ) async {
    await open(tester, app());
    for (final w in words) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.textContaining('Say: He is Allah, the One.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ayah-sheet-tafsir-text')),
      findsOneWidget,
    );
    // The whole tafsir, here: no "Read more".
    expect(find.text('Read more'), findsNothing);
    // The translator's note, listed under the translation.
    expect(find.byKey(const ValueKey('footnote-1')), findsOneWidget);
    expect(find.textContaining('He is Alone.'), findsOneWidget);
    // Off by default: word meanings and transliteration.
    expect(find.text('Allah'), findsNothing);
    expect(find.text('qul huwa allahu ahadun'), findsNothing);
  });

  testWidgets('word meanings, transliteration and the Quran font', (
    tester,
  ) async {
    await open(
      tester,
      app(
        view: const AyahViewPreferences(
          showTranslation: false,
          showWordMeanings: true,
          showTransliteration: true,
          quranFont: QuranFont.amiri,
        ),
      ),
    );
    expect(find.text('Allah'), findsOneWidget);
    expect(find.text('qul huwa allahu ahadun'), findsOneWidget);
    expect(find.textContaining('Say: He is Allah, the One.'), findsNothing);
    expect(find.byKey(const ValueKey('ayah-sheet-tafsir-text')), findsNothing);
    expect(
      tester.widget<Text>(find.text('ٱللَّهُ')).style?.fontFamily,
      QuranFont.amiri.family,
    );
  });

  testWidgets('its settings: Ayah mode\'s own, changed from here', (
    tester,
  ) async {
    await open(tester, app());
    await tester.tap(find.byKey(const ValueKey('ayah-sheet-view-options')));
    await tester.pumpAndSettle();
    // Not Ayah mode's layout.
    expect(find.byKey(const ValueKey('ayah-view-layout')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ayah-view-meanings')));
    await tester.pumpAndSettle();
    expect(find.text('Allah'), findsOneWidget);
  });

  testWidgets('no tafsir chosen: where to choose one', (tester) async {
    await open(tester, app(tafsirId: null));
    expect(
      find.text(
        'No tafsir chosen. Choose one in Settings → Translation & tafsir.',
      ),
      findsOneWidget,
    );
  });
}
