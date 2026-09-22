// The visual comparison this milestone's audit calls for, rendered through
// real Flutter/Skia (never just font/cmap inspection): the same
// representative ayahs as (A) VerseBlock's real canonical-text/system-font
// path, (B) VerseBlock's real QPC Hafs display-text/QPC Hafs-font path,
// and (C) the same QPC Hafs text forced through the system font (to show
// why the pairing matters -- this sandboxed test environment's system font
// renders Arabic as tofu regardless, a known, already-documented
// limitation of this environment, not evidence either way about a real
// device's own system font).
//
// Canonical word text below is copied verbatim from the real bundled
// assets/quran/quran_dataset.json (not the database import pipeline, to
// keep this test isolated and fast) -- see quran_display_providers_test
// .dart's own doc comment on why Quran text is never hand-retyped for a
// *comparison* assertion; here it is only ever opaque input, read back out
// of the real QPC Hafs manifest at run time for the actual checks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/application/uthmanic_hafs_font_providers.dart';
import 'package:tahfeez_ai/features/reader/application/quran_display_providers.dart';

// (chapterNo, verseNo, ayahId, label, real canonical words) for each
// representative ayah the audit named: Al-Fatiha (opening + closing, heavy
// diacritics), Ayat al-Kursi (long, several waqf/madd marks), the end of
// Al-Baqarah (a long, mark-dense ayah), Al-Ikhlas, and An-Nas (closing
// Surah of the Mushaf).
final _representativeAyahs = [
  (
    ayahId: 1001,
    label: 'Al-Fatiha 1:1 (Bismillah)',
    words: const ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'],
  ),
  (
    ayahId: 1007,
    label: 'Al-Fatiha 1:7',
    words: const [
      'صِرَٰطَ',
      'ٱلَّذِينَ',
      'أَنْعَمْتَ',
      'عَلَيْهِمْ',
      'غَيْرِ',
      'ٱلْمَغْضُوبِ',
      'عَلَيْهِمْ',
      'وَلَا',
      'ٱلضَّآلِّينَ',
    ],
  ),
  (
    ayahId: 2255,
    label: 'Ayat al-Kursi (2:255)',
    words: const [
      'ٱللَّهُ',
      'لَآ',
      'إِلَٰهَ',
      'إِلَّا',
      'هُوَ',
      'ٱلْحَىُّ',
      'ٱلْقَيُّومُ',
      'لَا',
      'تَأْخُذُهُۥ',
      'سِنَةٌ',
      'وَلَا',
      'نَوْمٌ',
      'لَّهُۥ',
      'مَا',
      'فِى',
      'ٱلسَّمَٰوَٰتِ',
      'وَمَا',
      'فِى',
      'ٱلْأَرْضِ',
      'مَن',
      'ذَا',
      'ٱلَّذِى',
      'يَشْفَعُ',
      'عِندَهُۥٓ',
      'إِلَّا',
      'بِإِذْنِهِۦ',
      'يَعْلَمُ',
      'مَا',
      'بَيْنَ',
      'أَيْدِيهِمْ',
      'وَمَا',
      'خَلْفَهُمْ',
      'وَلَا',
      'يُحِيطُونَ',
      'بِشَىْءٍ',
      'مِّنْ',
      'عِلْمِهِۦٓ',
      'إِلَّا',
      'بِمَا',
      'شَآءَ',
      'وَسِعَ',
      'كُرْسِيُّهُ',
      'ٱلسَّمَٰوَٰتِ',
      'وَٱلْأَرْضَ',
      'وَلَا',
      'يَـُٔودُهُۥ',
      'حِفْظُهُمَا',
      'وَهُوَ',
      'ٱلْعَلِىُّ',
      'ٱلْعَظِيمُ',
    ],
  ),
  (
    ayahId: 2286,
    label: 'End of Al-Baqarah (2:286)',
    words: const [
      'لَا',
      'يُكَلِّفُ',
      'ٱللَّهُ',
      'نَفْسًا',
      'إِلَّا',
      'وُسْعَهَا',
      'لَهَا',
      'مَا',
      'كَسَبَتْ',
      'وَعَلَيْهَا',
      'مَا',
      'ٱكْتَسَبَتْ',
      'رَبَّنَا',
      'لَا',
      'تُؤَاخِذْنَآ',
      'إِن',
      'نَّسِينَآ',
      'أَوْ',
      'أَخْطَأْنَا',
      'رَبَّنَا',
      'وَلَا',
      'تَحْمِلْ',
      'عَلَيْنَآ',
      'إِصْرًا',
      'كَمَا',
      'حَمَلْتَهُۥ',
      'عَلَى',
      'ٱلَّذِينَ',
      'مِن',
      'قَبْلِنَا',
      'رَبَّنَا',
      'وَلَا',
      'تُحَمِّلْنَا',
      'مَا',
      'لَا',
      'طَاقَةَ',
      'لَنَا',
      'بِهِۦ',
      'وَٱعْفُ',
      'عَنَّا',
      'وَٱغْفِرْ',
      'لَنَا',
      'وَٱرْحَمْنَآ',
      'أَنتَ',
      'مَوْلَىٰنَا',
      'فَٱنصُرْنَا',
      'عَلَى',
      'ٱلْقَوْمِ',
      'ٱلْكَٰفِرِينَ',
    ],
  ),
  (
    ayahId: 112001,
    label: 'Al-Ikhlas 112:1',
    words: const ['قُلْ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'],
  ),
  (
    ayahId: 114006,
    label: 'An-Nas 114:6',
    words: const ['مِنَ', 'ٱلْجِنَّةِ', 'وَٱلنَّاسِ'],
  ),
];

Widget _wordsRow(
  List<String> words, {
  String? fontFamily,
  required double fontSize,
}) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Wrap(
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final w in words)
          Text(
            w,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              color: Colors.black,
            ),
          ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUpAll(() async {
    container = ProviderContainer();
    await container.read(uthmanicHafsFontManifestProvider.future);
    await container.read(qpcHafsDisplayManifestProvider.future);
  });

  tearDownAll(() => container.dispose());

  testWidgets(
    'QPC V2... A) canonical/system vs B) QPC Hafs text+font vs C) QPC Hafs '
    'text/system font',
    (tester) async {
      final fontFamily = container
          .read(uthmanicHafsFontManifestProvider)
          .value
          ?.fontFamily;
      expect(fontFamily, isNotNull, reason: 'real font must load in tests');
      final displayRepository = container.read(quranDisplayRepositoryProvider);

      final rows = <Widget>[];
      for (final ref in _representativeAyahs) {
        final displayWords = displayRepository.displayWordsForAyah(ref.ayahId);
        expect(
          displayWords,
          isNotNull,
          reason: '${ref.label} must have a validated QPC Hafs entry',
        );
        expect(displayWords!.length, ref.words.length, reason: ref.label);

        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.label,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A) canonical text + system font',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                _wordsRow(ref.words, fontSize: 22),
                const SizedBox(height: 6),
                const Text(
                  'B) QPC Hafs text + QPC Hafs font',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                _wordsRow(displayWords, fontFamily: fontFamily, fontSize: 22),
                const SizedBox(height: 6),
                const Text(
                  'C) QPC Hafs text + system font',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                _wordsRow(displayWords, fontSize: 22),
                const Divider(height: 24),
              ],
            ),
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(900, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/verse_block_qpc_hafs_comparison.png'),
      );
    },
  );
}
