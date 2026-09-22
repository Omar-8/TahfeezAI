// Exercises VerseBlock's Arabic-text rendering against the real QPC Hafs
// display-word manifest and the real uthmanic_hafs.ttf font -- proving the
// whole "QPC Hafs display text + QPC Hafs font, with a correct
// canonical-text/system-font fallback" path actually renders through real
// Flutter/Skia, not just that the provider layer's data looks right in
// isolation.
//
// Builds its own `AyahWithWords` directly, with real canonical text
// (copied verbatim from assets/quran/quran_dataset.json, not the database
// import pipeline) rather than seeding a full Drift database through
// BundledDatasetSeeder — this keeps the test isolated to VerseBlock's own
// rendering logic and the two real providers it depends on.
//
// Deliberately never asserts against a hand-typed Arabic string literal for
// the *comparison* (see quran_display_providers_test.dart's own doc
// comment on why) -- the canonical text below is only ever used as opaque
// input, and every pass/fail check is a structural property (font family,
// font size) or a comparison against text this same test fetched from the
// real manifest at run time.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/application/uthmanic_hafs_font_providers.dart';
import 'package:tahfeez_ai/features/reader/application/quran_display_providers.dart';
import 'package:tahfeez_ai/features/reader/presentation/widgets/verse_block.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';

// Al-Ikhlas 112:1 ("قُلْ هُوَ ٱللَّهُ أَحَدٌ") -- copied verbatim from
// assets/quran/quran_dataset.json, the real bundled canonical dataset.
AyahWithWords _alIkhlasVerseOne() {
  const ayahId = 112001;
  return AyahWithWords(
    ayah: const Ayah(
      id: ayahId,
      chapterNo: 112,
      verseNo: 1,
      juzNo: 30,
      hizbNo: 60,
      rubNo: 4,
      manzilNo: 7,
      rukuNo: 556,
    ),
    words: const [
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 0, text: 'قُلْ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 1, text: 'هُوَ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 2, text: 'ٱللَّهُ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 3, text: 'أَحَدٌ'),
    ],
  );
}

// 37:130 -- the one ayah `build_qpc_hafs_display.dart` excludes (a genuine
// Tanzil/QPC Hafs word-segmentation difference on "الياسين"; see
// docs/QURAN_DATA_PROVENANCE.md §17). Real canonical text, 4 words.
AyahWithWords _surah37Ayah130() {
  const ayahId = 37130;
  return AyahWithWords(
    ayah: const Ayah(
      id: ayahId,
      chapterNo: 37,
      verseNo: 130,
      juzNo: 23,
      hizbNo: 45,
      rubNo: 3,
      manzilNo: 6,
      rukuNo: 449,
    ),
    words: const [
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 0, text: 'سَلَٰمٌ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 1, text: 'عَلَىٰٓ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 2, text: 'إِلْ'),
      AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: 3, text: 'يَاسِينَ'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late String? fontFamily;

  // A fresh container per test (not `setUpAll`): Riverpod schedules
  // provider-disposal via a `Timer` once a container's last listener (the
  // widget tree `pumpWidget` created) is torn down at the end of a test --
  // sharing one container across multiple `testWidgets` left that timer
  // pending into the *next* test's own strict "no pending timers" check.
  setUp(() async {
    container = ProviderContainer();
    fontFamily = (await container.read(uthmanicHafsFontManifestProvider.future))
        ?.fontFamily;
    await container.read(qpcHafsDisplayManifestProvider.future);
    expect(fontFamily, isNotNull, reason: 'real font must load in tests');
  });

  tearDown(() => container.dispose());

  Widget wrap(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets(
    'a real, validated ayah (Al-Ikhlas 112:1) renders through the QPC Hafs '
    'font, at the verse-mode font size, with the manifest\'s own text',
    (tester) async {
      final ayah = _alIkhlasVerseOne();
      final displayWords = container
          .read(quranDisplayRepositoryProvider)
          .displayWordsForAyah(ayah.ayah.id);
      expect(displayWords, hasLength(4));

      await tester.pumpWidget(
        wrap(
          VerseBlock(
            ayah: ayah,
            arabicVisible: true,
            isSelected: false,
            hasActiveSelection: false,
            onToggleSelection: () {},
          ),
        ),
      );
      await tester.pump();

      for (final word in displayWords!) {
        final textWidget = tester.widget<Text>(find.text(word));
        expect(textWidget.style?.fontFamily, fontFamily);
        expect(textWidget.style?.fontSize, 30.0);
      }
      // Never the canonical word text when the QPC Hafs word differs from
      // it (both are real Quran text, but distinct orthographic choices --
      // if canonical happened to equal QPC Hafs for every word here this
      // assertion would be vacuous, so guard that it isn't).
      final anyDiffer = List.generate(
        ayah.words.length,
        (i) => ayah.words[i].text,
      ).asMap().entries.any((e) => e.value != displayWords[e.key]);
      expect(
        anyDiffer,
        isTrue,
        reason:
            'expected at least one word to visibly differ between '
            'canonical and QPC Hafs text for this ayah',
      );
    },
  );

  testWidgets(
    'the one build-time-excluded ayah (37:130) falls back to canonical '
    'text through the system font -- never a mismatched QPC Hafs render',
    (tester) async {
      final ayah = _surah37Ayah130();
      expect(
        container
            .read(quranDisplayRepositoryProvider)
            .displayWordsForAyah(37130),
        isNull,
      );

      await tester.pumpWidget(
        wrap(
          VerseBlock(
            ayah: ayah,
            arabicVisible: true,
            isSelected: false,
            hasActiveSelection: false,
            onToggleSelection: () {},
          ),
        ),
      );
      await tester.pump();

      for (final word in ayah.words) {
        final textWidget = tester.widget<Text>(find.text(word.text));
        // `fontFamily: null` -- the honest system-font fallback, never the
        // QPC Hafs font painting mismatched canonical text.
        expect(textWidget.style?.fontFamily, isNull);
      }
    },
  );
}
