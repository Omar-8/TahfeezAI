import '../../quran/domain/models/quran_refs.dart';
import 'models/memorization_models.dart';

/// How a word went in a recitation test.
enum WordOutcome {
  correct,

  /// Said as something else.
  wrong,

  /// Passed over, or revealed by hand in hide mode.
  skipped,

  /// Said wrong, then corrected by the reciter.
  selfCorrected,
}

/// One word a test covered.
class TestWord {
  const TestWord(this.ref, this.outcome, {this.pronunciationMistake = false});

  final WordRef ref;
  final WordOutcome outcome;

  /// The right word, but a pronunciation mistake heard in it.
  final bool pronunciationMistake;
}

/// Grades every ayah a test covered **whole** (each of its [ayahWords]
/// words among [words]); ayahs only partly recited are not graded.
///
/// - [AyahGrade.fail]: a word wrong or skipped;
/// - [AyahGrade.hard]: a self-correction or a pronunciation mistake;
/// - [AyahGrade.good]: clean.
///
/// Pronunciation mistakes make an ayah hard, never failed: memorization is
/// about the words.
List<AyahAttempt> gradeTest(
  Iterable<TestWord> words, {
  required int Function(int ayahId) ayahWords,
  required String sessionId,
  required DateTime at,
  required bool hidden,
}) {
  final byAyah = <int, Map<int, TestWord>>{};
  for (final w in words) {
    (byAyah[w.ref.ayahId] ??= {})[w.ref.wordIndex] = w;
  }
  final out = <AyahAttempt>[];
  for (final MapEntry(key: ayahId, value: ws) in byAyah.entries) {
    final n = ayahWords(ayahId);
    if (n <= 0 || ws.length < n) continue;
    int count(bool Function(TestWord) test) => ws.values.where(test).length;
    final wrong = count((w) => w.outcome == WordOutcome.wrong);
    final skipped = count((w) => w.outcome == WordOutcome.skipped);
    final corrected = count((w) => w.outcome == WordOutcome.selfCorrected);
    final pronunciation = count(
      (w) => w.pronunciationMistake && w.outcome == WordOutcome.correct,
    );
    out.add(
      AyahAttempt(
        ayahId: ayahId,
        sessionId: sessionId,
        at: at,
        grade: wrong + skipped > 0
            ? AyahGrade.fail
            : corrected + pronunciation > 0
            ? AyahGrade.hard
            : AyahGrade.good,
        words: n,
        wrong: wrong,
        skipped: skipped,
        selfCorrected: corrected,
        pronunciation: pronunciation,
        hidden: hidden,
      ),
    );
  }
  out.sort((a, b) => a.ayahId.compareTo(b.ayahId));
  return out;
}
