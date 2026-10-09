import 'models/memorization_models.dart';

/// How a set of recitations went, overall: memorization (the words) and
/// tajweed (how they were pronounced).
class RecitationScore {
  const RecitationScore({
    this.ayahs = 0,
    this.words = 0,
    this.missedWords = 0,
    this.pronunciation = 0,
    this.good = 0,
    this.hesitant = 0,
    this.missed = 0,
  });

  /// From [attempts] (each ayah each time it was recited).
  factory RecitationScore.of(Iterable<AyahAttempt> attempts) {
    var ayahs = 0, words = 0, missedWords = 0, pronunciation = 0;
    var good = 0, hesitant = 0, missed = 0;
    for (final a in attempts) {
      ayahs++;
      words += a.words;
      missedWords += a.wrong + a.skipped;
      pronunciation += a.pronunciation;
      switch (a.grade) {
        case AyahGrade.good:
          good++;
        case AyahGrade.hard:
          hesitant++;
        case AyahGrade.fail:
          missed++;
      }
    }
    return RecitationScore(
      ayahs: ayahs,
      words: words,
      missedWords: missedWords,
      pronunciation: pronunciation,
      good: good,
      hesitant: hesitant,
      missed: missed,
    );
  }

  /// Ayahs recited (each time), words in them, words wrong or skipped, words
  /// said right but with a pronunciation mistake.
  final int ayahs, words, missedWords, pronunciation;

  /// Ayahs graded good, hesitant (hard) and missed (fail).
  final int good, hesitant, missed;

  bool get isEmpty => words == 0;

  /// The share of words said right (0-1).
  double get memorization => words == 0 ? 0 : 1 - missedWords / words;

  /// Of the words said right, the share with no pronunciation mistake (0-1).
  double get tajweed {
    final right = words - missedWords;
    return right <= 0 ? 0 : 1 - pronunciation / right;
  }
}
