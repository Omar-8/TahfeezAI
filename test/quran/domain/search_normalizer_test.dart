import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/search_normalizer.dart';

void main() {
  const normalizer = SearchNormalizer();

  group('normalizeArabic', () {
    test('strips tashkeel (diacritics)', () {
      // بِسْمِ (with kasra, sukun) -> بسم
      expect(normalizer.normalizeArabic('بِسْمِ'), 'بسم');
    });

    test('strips tatweel', () {
      expect(normalizer.normalizeArabic('كـتـاب'), 'كتاب');
    });

    test('folds hamza-bearing alef variants to bare alef', () {
      expect(normalizer.normalizeArabic('أحمد'), 'احمد');
      expect(normalizer.normalizeArabic('إبراهيم'), 'ابراهيم');
      expect(normalizer.normalizeArabic('آدم'), 'ادم');
    });

    test('folds alef-maksura to yaa', () {
      expect(normalizer.normalizeArabic('موسى'), 'موسي');
    });

    test('collapses whitespace and trims', () {
      expect(normalizer.normalizeArabic('  الله   اكبر  '), 'الله اكبر');
    });

    test('two differently-diacritized spellings normalize identically', () {
      final a = normalizer.normalizeArabic('الرَّحْمَٰنِ');
      final b = normalizer.normalizeArabic('الرحمن');
      expect(a, b);
    });
  });

  group('normalizeLatin', () {
    test('lowercases and trims', () {
      expect(normalizer.normalizeLatin('  Al-Baqarah  '), 'al-baqarah');
    });

    test('collapses internal whitespace', () {
      expect(normalizer.normalizeLatin('In   the   name'), 'in the name');
    });
  });

  group('tokenize', () {
    test('splits on whitespace after normalizing', () {
      expect(normalizer.tokenize('In the Beginning', arabicScript: false), [
        'in',
        'the',
        'beginning',
      ]);
    });

    test('drops tokens shorter than 2 characters', () {
      expect(normalizer.tokenize('a of the sea', arabicScript: false), [
        'of',
        'the',
        'sea',
      ]);
    });

    test('drops tokens with no letter or digit', () {
      expect(normalizer.tokenize('hello -- world !!', arabicScript: false), [
        'hello',
        'world',
      ]);
    });

    test('keeps numeric tokens', () {
      expect(normalizer.tokenize('surah 12 verse', arabicScript: false), [
        'surah',
        '12',
        'verse',
      ]);
    });

    test('returns an empty list for an all-punctuation query', () {
      expect(normalizer.tokenize('!!! ...', arabicScript: false), isEmpty);
    });

    test('tokenizes Arabic text after Arabic-specific normalization', () {
      expect(normalizer.tokenize('بِسْمِ اللَّهِ', arabicScript: true), [
        'بسم',
        'الله',
      ]);
    });
  });
}
