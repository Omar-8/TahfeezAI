import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/domain/reader_layout_item.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

Surah _surah(int surahNo) => Surah(
  surahNo: surahNo,
  ayahCount: 7,
  revelationOrder: surahNo,
  rukusCount: 1,
  revelationType: RevelationType.meccan,
);

Ayah _ayah(int chapterNo, int verseNo) => Ayah(
  id: chapterNo * 1000 + verseNo,
  chapterNo: chapterNo,
  verseNo: verseNo,
  juzNo: 1,
  hizbNo: 1,
  rubNo: 1,
  manzilNo: 1,
  rukuNo: 1,
);

void main() {
  test(
    'keys are unique across every variant and stable for the same content',
    () {
      final items = <(ReaderLayoutItem, int)>[
        (ReaderLayoutItem.chapterInfo(surah: _surah(1)), 0),
        (const ReaderLayoutItem.bismillah(), 1),
        (const ReaderLayoutItem.chapterTitle(surahNo: 2), 2),
        (const ReaderLayoutItem.sectionMarker(label: 'Ruku 1'), 3),
        (
          ReaderLayoutItem.verse(
            AyahWithWords(ayah: _ayah(1, 1), words: const []),
          ),
          4,
        ),
      ];

      final keys = items.map((e) => readerLayoutItemKey(e.$1, e.$2)).toList();
      expect(keys.toSet(), hasLength(keys.length));
    },
  );

  test('verse keys are derived from the ayah id, not list position', () {
    final verse = ReaderLayoutItem.verse(
      AyahWithWords(ayah: _ayah(2, 5), words: const []),
    );
    expect(readerLayoutItemKey(verse, 0), readerLayoutItemKey(verse, 99));
    expect(readerLayoutItemKey(verse, 0), 'verse-2005');
  });

  test('chapterInfo keys are derived from the surah number', () {
    final item = ReaderLayoutItem.chapterInfo(surah: _surah(18));
    expect(readerLayoutItemKey(item, 3), 'chapter-info-18');
  });

  test('bismillah and sectionMarker keys include position (can repeat per session)', () {
    const a = ReaderLayoutItem.bismillah();
    expect(readerLayoutItemKey(a, 0), isNot(readerLayoutItemKey(a, 1)));
  });
}
