import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/quran_location_path.dart';

void main() {
  group('quranLocationPath / quranLocationFromPath round-trip', () {
    final cases = <QuranLocation>[
      const QuranLocation.surah(2),
      const QuranLocation.ayah(2, 255),
      const QuranLocation.ayahRange(2, 1, 5),
      const QuranLocation.juz(5),
      const QuranLocation.hizb(10),
      const QuranLocation.page(1, 42),
    ];

    for (final location in cases) {
      test('round-trips $location', () {
        final path = quranLocationPath(location);
        expect(quranLocationFromPath(path), location);
      });
    }
  });

  test('produces the expected literal path shape for each kind', () {
    expect(quranLocationPath(const QuranLocation.surah(2)), 'surah/2');
    expect(quranLocationPath(const QuranLocation.ayah(2, 255)), 'ayah/2/255');
    expect(
      quranLocationPath(const QuranLocation.ayahRange(2, 1, 5)),
      'ayah-range/2/1/5',
    );
    expect(quranLocationPath(const QuranLocation.juz(5)), 'juz/5');
    expect(quranLocationPath(const QuranLocation.hizb(10)), 'hizb/10');
    expect(quranLocationPath(const QuranLocation.page(1, 42)), 'page/1/42');
  });

  group('quranLocationFromPath rejects malformed input', () {
    for (final bad in [
      'unknown/2',
      'surah/not-a-number',
      'surah',
      'ayah/2',
      '',
      'surah/2/extra',
    ]) {
      test('returns null for "$bad"', () {
        expect(quranLocationFromPath(bad), isNull);
      });
    }
  });
}
