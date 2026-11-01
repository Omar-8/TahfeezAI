import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/quran/domain/models/tajweed_models.dart';

void main() {
  final index = TajweedIndex.fromJson({
    'rules': ['qalqalah', 'madd_6', 'not_a_rule'],
    'text_sha256': 'x',
    'ayahs': {
      // (word, start, end, rule) quadruples.
      '15007': [0, 1, 3, 1, 1, 0, 2, 0, 1, 0, 1, 2, 1, 5, 9, 0],
    },
  });

  test('the asset: each word\'s spans, by rule; unknown rules left out', () {
    expect(index.spansOf(15007, 0), const [
      TajweedSpan(1, 3, TajweedGroup.maddNecessary),
    ]);
    expect(index.spansOf(15007, 1), const [
      TajweedSpan(0, 2, TajweedGroup.qalqala),
      TajweedSpan(5, 9, TajweedGroup.qalqala),
    ]);
    expect(index.spansOf(1001, 0), isEmpty);
  });

  test('words shown joined: each one\'s spans moved past the ones before; '
      'a span beyond its word dropped', () {
    expect(index.spansIn(15007, 0, ['abcd', 'efg']), const [
      TajweedSpan(1, 3, TajweedGroup.maddNecessary),
      TajweedSpan(5, 7, TajweedGroup.qalqala),
    ]);
  });

  test('the word drawn in runs: coloured letters, the rest its own ink', () {
    expect(
      tajweedRuns('abcdef', const [
        TajweedSpan(1, 3, TajweedGroup.qalqala),
        TajweedSpan(2, 4, TajweedGroup.maddNecessary),
      ]),
      [
        ('a', null),
        ('b', TajweedGroup.qalqala),
        ('cd', TajweedGroup.maddNecessary),
        ('ef', null),
      ],
    );
  });
}
