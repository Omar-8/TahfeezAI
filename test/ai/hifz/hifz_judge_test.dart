// Hifz-mode judging of live recitation: the real matcher over the real
// canonical corpus, fed recognizer-spelled Āyat al-Kursī (2:255, 50 words)
// with controlled mistakes, streamed word by word like live partials.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/ai/matching/quran_match_normalizer.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../matching/corpus_fixture.dart';
import '../matching/quran_stream_matcher_cases_test.dart' show kursi;

void main() {
  final corpus = loadTestCorpus();
  const n = QuranMatchNormalizer();
  final start = corpus.verseStartPosition((chapterNo: 2, verseNo: 255))!;
  final end = corpus.verseEndPosition((chapterNo: 2, verseNo: 255))!;

  WordRef refOf(String heard, {int nth = 1}) {
    var seen = 0;
    for (var p = start; p <= end; p++) {
      if (quranWordSimilarity(corpus.words[p].key, n.key(heard)) == 1 &&
          ++seen == nth) {
        return corpus.words[p].ref;
      }
    }
    throw StateError('no "$heard" in 2:255');
  }

  /// Streams each of [segments] word by word, then as a final; a pause
  /// (flush) between segments.
  (HifzJudge, List<HifzEvent>) recite(
    List<String> segments, {
    bool strict = true,
  }) {
    final matcher = QuranStreamMatcher(corpus)
      ..start(anchor: start, trustAnchor: true);
    final judge = HifzJudge(
      corpus,
      start: start,
      end: end,
      config: HifzConfig(strict: strict),
    );
    final events = <HifzEvent>[];
    void feed(List<QuranMatchEvent> out) {
      for (final e in out.whereType<WordHeard>()) {
        events.addAll(judge.onHeard(e));
      }
    }

    for (final segment in segments) {
      final words = segment.split(' ');
      for (var k = 1; k < words.length; k++) {
        feed(matcher.onPartial(words.take(k).join(' ')));
      }
      feed(matcher.onFinal(segment));
      feed(matcher.flush()); // pause
    }
    return (judge, events);
  }

  List<HifzVerdict> verdictsOf(List<HifzEvent> events) => [
    for (final e in events) e.verdict,
  ];

  test('correct recitation reveals every word in order', () {
    final (judge, events) = recite([kursi]);
    expect(verdictsOf(events), List.filled(50, HifzVerdict.correct));
    expect(judge.completed, isTrue);
    expect(judge.revealed, hasLength(50));
  });

  test('wrong word (strict): marked, nothing more revealed until fixed', () {
    final upTo = kursi.substring(0, kursi.indexOf('وما خلفهم'));
    final (judge, events) = recite(['$upToوما خلفنا ولا يحيطون بشيء من علمه']);
    final khalfahum = refOf('خلفهم');
    final wrong = events.where((e) => e.verdict == HifzVerdict.wrong).single;
    expect(wrong.ref, khalfahum);
    expect(wrong.heard, 'خلفنا');
    expect(judge.expectedRef, khalfahum, reason: 'waiting for correction');
    expect(judge.pending, HifzVerdict.wrong);
    expect(judge.revealed.contains(corpus.positionOf(khalfahum)), isFalse);
    expect(judge.revealed, hasLength(31), reason: 'only words before it');
  });

  test('self-correction after a wrong word', () {
    final (judge, events) = recite([
      kursi.replaceFirst('وما خلفهم', 'وما خلفنا وما خلفهم'),
    ]);
    final khalfahum = refOf('خلفهم');
    expect(events.where((e) => e.ref == khalfahum).map((e) => e.verdict), [
      HifzVerdict.wrong,
      HifzVerdict.selfCorrected,
    ]);
    expect(judge.completed, isTrue);
    expect(judge.counts[HifzVerdict.wrong], 1);
    expect(judge.counts[HifzVerdict.selfCorrected], 1);
  });

  test('skipped word (strict): held until the reciter goes back', () {
    final skipped = kursi.replaceFirst('سنه ', '');
    final (held, heldEvents) = recite([skipped]);
    final sinah = refOf('سنه');
    expect(
      heldEvents.where((e) => e.verdict == HifzVerdict.skipped).single.ref,
      sinah,
    );
    expect(held.expectedRef, sinah);
    expect(held.completed, isFalse);

    // Going back to say it: corrected, and the test continues.
    final words = kursi.split(' ');
    final at = words.indexOf('سنه');
    final (judge, events) = recite([
      '${words.take(at).join(' ')} ولا نوم',
      words.skip(at).join(' '),
    ]);
    expect(events.where((e) => e.ref == sinah).map((e) => e.verdict), [
      HifzVerdict.skipped,
      HifzVerdict.selfCorrected,
    ]);
    expect(judge.completed, isTrue);
  });

  test('skipped word (lenient): marked, revealed, test moves on', () {
    final (judge, events) = recite([
      kursi.replaceFirst('سنه ', ''),
    ], strict: false);
    final sinah = refOf('سنه');
    expect(
      events.where((e) => e.verdict == HifzVerdict.skipped).single.ref,
      sinah,
    );
    expect(judge.marked[corpus.positionOf(sinah)], HifzVerdict.skipped);
    expect(judge.completed, isTrue);
    expect(judge.counts[HifzVerdict.correct], 49);
  });

  test('wrong word (lenient): marked and revealed', () {
    final (judge, events) = recite([
      kursi.replaceFirst('وما خلفهم', 'وما خلفنا'),
    ], strict: false);
    final khalfahum = refOf('خلفهم');
    expect(
      events.where((e) => e.verdict == HifzVerdict.wrong).single.ref,
      khalfahum,
    );
    expect(judge.marked[corpus.positionOf(khalfahum)], HifzVerdict.wrong);
    expect(judge.completed, isTrue);
  });

  test('repeated word', () {
    final (judge, events) = recite([kursi.replaceFirst('الحي ', 'الحي الحي ')]);
    expect(
      events.where((e) => e.verdict == HifzVerdict.repeated).single.ref,
      refOf('الحي'),
    );
    expect(judge.counts[HifzVerdict.correct], 50);
    expect(judge.completed, isTrue);
  });

  test('extra words (hesitation fillers) do not advance or break', () {
    final (judge, events) = recite([
      kursi.replaceFirst('يشفع ', 'يشفع امم اه '),
    ]);
    expect(judge.counts[HifzVerdict.extra], 2);
    expect(judge.counts[HifzVerdict.correct], 50);
    expect(events.where((e) => e.verdict == HifzVerdict.wrong), isEmpty);
    expect(judge.completed, isTrue);
  });

  test('uncertain: only similar-sounding letters differ', () {
    // «صنه» for «سنه»: a recognition or pronunciation matter, not a
    // different word.
    final (judge, events) = recite([kursi.replaceFirst('سنه', 'صنه')]);
    final sinah = refOf('سنه');
    expect(
      events.where((e) => e.verdict == HifzVerdict.uncertain).single.ref,
      sinah,
    );
    expect(judge.marked[corpus.positionOf(sinah)], HifzVerdict.uncertain);
    expect(events.where((e) => e.verdict == HifzVerdict.wrong), isEmpty);
    expect(judge.completed, isTrue);
  });

  test('a different word form is wrong, not uncertain', () {
    // «ايدينا» for «ايديهم»: the wrong pronoun — a real memorization slip.
    final (judge, events) = recite([kursi.replaceFirst('ايديهم', 'ايدينا')]);
    expect(
      events.where((e) => e.verdict == HifzVerdict.wrong).single.ref,
      refOf('ايديهم'),
    );
    expect(judge.pending, HifzVerdict.wrong);
  });

  test('pauses between segments lose nothing', () {
    final words = kursi.split(' ');
    final (judge, events) = recite([
      words.take(7).join(' '),
      words.skip(7).take(15).join(' '),
      words.skip(22).join(' '),
    ]);
    expect(verdictsOf(events), List.filled(50, HifzVerdict.correct));
    expect(judge.completed, isTrue);
  });

  group('live and manual control', () {
    HifzJudge newJudge() => HifzJudge(corpus, start: start, end: end);
    QuranStreamMatcher newMatcher() =>
        QuranStreamMatcher(corpus)..start(anchor: start, trustAnchor: true);
    List<HifzEvent> feed(HifzJudge judge, List<QuranMatchEvent> out) => [
      for (final e in out.whereType<WordHeard>()) ...judge.onHeard(e),
    ];

    test('the word just said is revealed at once, and counted once', () {
      final judge = newJudge();
      final matcher = newMatcher();
      feed(judge, matcher.onPartial('الله'));
      expect(judge.revealed, hasLength(1), reason: 'no need to say the next');
      feed(judge, matcher.onPartial('الله لا'));
      feed(judge, matcher.onPartial('الله لا اله'));
      expect(judge.revealed, hasLength(3));
      expect(judge.expectedRef, corpus.words[start + 3].ref);
      final events = feed(judge, matcher.onFinal('الله لا اله الا'))
        ..addAll(feed(judge, matcher.flush()));
      expect(judge.revealed, hasLength(4));
      expect(judge.counts[HifzVerdict.correct], 4);
      expect(events.where((e) => e.verdict == HifzVerdict.repeated), isEmpty);
    });

    test('a half-heard word is not judged early', () {
      final judge = newJudge();
      final matcher = newMatcher();
      feed(judge, matcher.onPartial('الله لا اله الا هو الحي الق'));
      expect(judge.expectedRef, corpus.words[start + 6].ref);
      expect(judge.counts[HifzVerdict.wrong], 0);
      feed(judge, matcher.onPartial('الله لا اله الا هو الحي القيوم'));
      expect(judge.revealed, hasLength(7));
    });

    test('revealing without reciting counts as skipped', () {
      final judge = newJudge();
      final one = judge.revealManually();
      expect(one.single.verdict, HifzVerdict.skipped);
      expect(one.single.ref, corpus.words[start].ref);
      final rest = judge.revealManually(wholeAyah: true);
      expect(rest, hasLength(49), reason: 'the rest of 2:255');
      expect(judge.completed, isTrue);
      expect(judge.counts[HifzVerdict.skipped], 50);
    });

    test('hiding back re-hides words and expects them again', () {
      final judge = newJudge();
      final matcher = newMatcher();
      feed(judge, matcher.onPartial('الله لا اله الا هو الحي'));
      expect(judge.revealed, hasLength(6));
      expect(judge.hideBack(), isTrue);
      expect(judge.revealed, hasLength(5));
      expect(judge.expectedRef, corpus.words[start + 5].ref);
      expect(judge.hideBack(wholeAyah: true), isTrue);
      expect(judge.revealed, isEmpty);
      expect(judge.hideBack(), isFalse, reason: 'start of the range');
    });

    test('going back over recited words: followed word by word, then back '
        'to the next new word', () {
      final judge = newJudge();
      final matcher = newMatcher();
      final words = kursi.split(' ');
      feed(judge, matcher.onFinal(words.take(20).join(' ')));
      feed(judge, matcher.flush());
      expect(judge.expected, start + 20);
      expect(judge.reviewing, isNull);

      // Starting the ayah again: followed as each word is heard.
      feed(judge, matcher.onPartial('الله'));
      expect(judge.current, start + 1);
      feed(judge, matcher.onPartial('الله لا'));
      expect(judge.current, start + 2);
      feed(judge, matcher.onPartial('الله لا اله'));
      expect(judge.current, start + 3);
      expect(judge.expected, start + 20, reason: 'progress is kept');

      // Catching up and going on: back to new words, nothing re-judged.
      final events = feed(judge, matcher.onFinal(words.take(22).join(' ')))
        ..addAll(feed(judge, matcher.flush()));
      expect(judge.reviewing, isNull);
      expect(judge.expected, start + 22);
      expect(judge.counts[HifzVerdict.correct], 22);
      expect(events.where((e) => e.verdict == HifzVerdict.wrong), isEmpty);
    });

    test('starting after words already revealed by hand', () {
      final judge = newJudge()..preReveal(10);
      expect(judge.revealed, hasLength(10));
      expect(judge.expectedRef, corpus.words[start + 10].ref);
    });
  });
}
