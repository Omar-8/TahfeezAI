import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine_ref_adapter.dart';

void main() {
  group('QuranEngineRefAdapter.ayahIdOf/verseRefOf', () {
    test('computes the stable ayahId using chapterNo * 1000 + verseNo', () {
      expect(QuranEngineRefAdapter.ayahIdOf(surahNo: 2, ayahNo: 255), 2255);
      expect(QuranEngineRefAdapter.ayahIdOf(surahNo: 114, ayahNo: 6), 114006);
    });

    test('builds a canonical VerseRef', () {
      final ref = QuranEngineRefAdapter.verseRefOf(surahNo: 2, ayahNo: 255);
      expect(ref.chapterNo, 2);
      expect(ref.verseNo, 255);
    });
  });

  group('QuranEngineRefAdapter.verseRefFromEngineKey', () {
    test('parses "surah:ayah"', () {
      final ref = QuranEngineRefAdapter.verseRefFromEngineKey('2:255');
      expect(ref.chapterNo, 2);
      expect(ref.verseNo, 255);
    });

    test('throws FormatException on a malformed key', () {
      expect(
        () => QuranEngineRefAdapter.verseRefFromEngineKey('2:255:7'),
        throwsFormatException,
      );
      expect(
        () => QuranEngineRefAdapter.verseRefFromEngineKey('not-a-key'),
        throwsFormatException,
      );
    });
  });

  group('QuranEngineRefAdapter.wordRefFromEngineKey', () {
    test('parses "surah:ayah:word" and converts the 1-based engine word index '
        'to a 0-based canonical wordIndex', () {
      final ref = QuranEngineRefAdapter.wordRefFromEngineKey('2:255:7');
      expect(ref.ayahId, 2255);
      expect(ref.wordIndex, 6);
    });

    test('the very first word of the Mushaf ("1:1:1") maps to wordIndex 0', () {
      final ref = QuranEngineRefAdapter.wordRefFromEngineKey('1:1:1');
      expect(ref.ayahId, 1001);
      expect(ref.wordIndex, 0);
    });

    test('throws FormatException on a malformed key', () {
      expect(
        () => QuranEngineRefAdapter.wordRefFromEngineKey('2:255'),
        throwsFormatException,
      );
    });
  });

  group('QuranEngineRefAdapter.engineKeyFromWordRef', () {
    test('is the exact inverse of wordRefFromEngineKey', () {
      const original = '2:255:7';
      final ref = QuranEngineRefAdapter.wordRefFromEngineKey(original);
      expect(QuranEngineRefAdapter.engineKeyFromWordRef(ref), original);
    });

    test('round-trips the first word of the Mushaf', () {
      const original = '1:1:1';
      final ref = QuranEngineRefAdapter.wordRefFromEngineKey(original);
      expect(QuranEngineRefAdapter.engineKeyFromWordRef(ref), original);
    });
  });
}
