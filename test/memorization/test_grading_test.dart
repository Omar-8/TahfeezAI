import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/test_grading.dart';

void main() {
  final at = DateTime(2026, 10, 1);
  // Al-Ikhlas: 4, 2, 4 and 5 words.
  int words(int ayah) =>
      const {112001: 4, 112002: 2, 112003: 4, 112004: 5}[ayah]!;
  List<TestWord> ayah(
    int id, [
    Map<int, WordOutcome> outcomes = const {},
    Set<int> pronunciation = const {},
  ]) => [
    for (var w = 0; w < words(id); w++)
      TestWord(
        (ayahId: id, wordIndex: w),
        outcomes[w] ?? WordOutcome.correct,
        pronunciationMistake: pronunciation.contains(w),
      ),
  ];
  List<AyahAttempt> grade(List<TestWord> ws, {bool hidden = true}) =>
      gradeTest(ws, ayahWords: words, sessionId: 's1', at: at, hidden: hidden);

  test('clean ayahs are good; only ayahs recited whole are graded', () {
    final out = grade([
      ...ayah(112001),
      ...ayah(112002),
      ...ayah(112003).take(2),
    ]);
    expect(
      [for (final a in out) (a.ayahId, a.grade)],
      [(112001, AyahGrade.good), (112002, AyahGrade.good)],
    );
    expect(out.first.words, 4);
    expect(out.first.hidden, isTrue);
    expect(out.first.sessionId, 's1');
  });

  test('a word wrong or skipped fails the ayah', () {
    final out = grade([
      ...ayah(112001, {1: WordOutcome.wrong}),
      ...ayah(112002, {0: WordOutcome.skipped}),
    ]);
    expect(out.map((a) => a.grade), everyElement(AyahGrade.fail));
    expect((out[0].wrong, out[1].skipped), (1, 1));
  });

  test('a self-correction or a pronunciation mistake makes it hard, not '
      'failed', () {
    final out = grade([
      ...ayah(112001, {2: WordOutcome.selfCorrected}),
      ...ayah(112003, {}, {1, 3}),
    ]);
    expect(out.map((a) => a.grade), everyElement(AyahGrade.hard));
    expect(out[0].selfCorrected, 1);
    expect(out[1].pronunciation, 2);
  });

  test('nothing covered whole: nothing graded', () {
    expect(grade(ayah(112004).take(4).toList()), isEmpty);
  });
}
