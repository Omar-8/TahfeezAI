import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/recitation_score.dart';

void main() {
  AyahAttempt a(
    AyahGrade g, {
    int words = 10,
    int wrong = 0,
    int skipped = 0,
    int pronunciation = 0,
  }) => AyahAttempt(
    ayahId: 1,
    sessionId: 's',
    at: DateTime(2026),
    grade: g,
    words: words,
    wrong: wrong,
    skipped: skipped,
    pronunciation: pronunciation,
  );

  test('memorization: words said right; tajweed: of those, without a '
      'pronunciation mistake', () {
    final s = RecitationScore.of([
      a(AyahGrade.good),
      a(AyahGrade.fail, wrong: 1, skipped: 1),
      a(AyahGrade.hard, pronunciation: 2),
    ]);
    expect((s.ayahs, s.words, s.missedWords), (3, 30, 2));
    expect(s.memorization, closeTo(28 / 30, 1e-9));
    expect(s.tajweed, closeTo(26 / 28, 1e-9));
    expect((s.good, s.hesitant, s.missed), (1, 1, 1));
  });

  test('nothing recited: empty', () {
    expect(RecitationScore.of(const []).isEmpty, isTrue);
  });
}
