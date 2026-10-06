import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/matching/quran_match_normalizer.dart';

void main() {
  const n = QuranMatchNormalizer();
  double sim(String uthmani, String heard) =>
      quranWordSimilarity(n.key(uthmani), n.key(heard));

  test('folds Uthmani spelling onto recognizer spelling', () {
    expect(n.key('ٱلسَّمَٰوَٰتِ'), 'السماوات');
    expect(n.key('ٱللَّهُ'), 'الله');
    expect(n.key('سِنَةٌ'), 'سنه');
    expect(n.key('تَأْخُذُهُۥ'), 'تاخذه');
    expect(n.key('يَٰٓأَيُّهَا'), 'ياايها');
    expect(n.key('شَىْءٍ'), 'شي');
  });

  test('similar words score high, different words low', () {
    expect(sim('ٱلسَّمَٰوَٰتِ', 'السماوات'), 1);
    expect(sim('هَٰذَا', 'هذا'), 1, reason: 'alef-free skeleton');
    expect(sim('ٱلصَّلَوٰةَ', 'الصلاه'), greaterThanOrEqualTo(0.8));
    expect(sim('يَـُٔودُهُۥ', 'يؤوده'), greaterThanOrEqualTo(0.75));
    expect(sim('خَلْفَهُمْ', 'بعدهم'), lessThan(0.6));
    expect(sim('لَا', 'ما'), lessThan(0.5), reason: 'short words need exact');
  });

  test('keysOf drops tokens without Arabic letters', () {
    expect(n.keysOf('الله  لا 123 اله .'), ['الله', 'لا', 'اله']);
  });
}
