// Difficult recitation cases for QuranStreamMatcher, built from real
// recognizer spelling of Āyat al-Kursī (2:255) — the Android recognizer's
// final transcript from Milestone R2 — with controlled edits.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/matching/quran_match_normalizer.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import 'corpus_fixture.dart';

const kursi =
    'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السماوات '
    'وما في الارض من ذا الذي يشفع عنده الا باذنه يعلم ما بين ايديهم وما '
    'خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السماوات والارض '
    'ولا يؤوده حفظهما وهو العلي العظيم';

void main() {
  final corpus = loadTestCorpus();
  const n = QuranMatchNormalizer();
  const verse = (chapterNo: 2, verseNo: 255);
  final start = corpus.verseStartPosition(verse)!;
  final end = corpus.verseEndPosition(verse)!;
  final kursiRefs = [for (var p = start; p <= end; p++) corpus.words[p].ref];

  /// The [nth] word of 2:255 (from 1) whose text matches [heard].
  WordRef refOf(String heard, {int nth = 1}) {
    var seen = 0;
    for (var p = start; p <= end; p++) {
      if (quranWordSimilarity(corpus.words[p].key, n.key(heard)) == 1 &&
          ++seen == nth) {
        return corpus.words[p].ref;
      }
    }
    throw StateError('no "$heard" #$nth in 2:255');
  }

  /// Streams [text] word by word as partials, then as one final.
  List<QuranMatchEvent> recite(
    String text, {
    int? anchor,
    (int, int)? focus,
    List<String>? log,
  }) {
    final matcher = QuranStreamMatcher(corpus, log: log?.add)
      ..start(anchor: anchor ?? start);
    if (focus != null) matcher.setFocus(focus.$1, focus.$2);
    final words = text.split(' ');
    return [
      for (var k = 1; k < words.length; k++)
        ...matcher.onPartial(words.take(k).join(' ')),
      ...matcher.onFinal(text),
      ...matcher.flush(),
    ];
  }

  List<WordRef> refs<T extends QuranMatchEvent>(List<QuranMatchEvent> events) =>
      [
        for (final e in events.whereType<T>())
          switch (e) {
            WordConfirmed(:final ref) ||
            WordSkipped(:final ref) ||
            WordRepeated(:final ref) ||
            PossibleMistake(:final ref) => ref,
            _ => throw StateError('$e'),
          },
      ];

  test('clean recitation confirms every word once, in order', () {
    final log = <String>[];
    final events = recite(kursi, log: log);
    expect(refs<WordConfirmed>(events), kursiRefs);
    expect(events.whereType<PossibleMistake>(), isEmpty);
    expect(events.whereType<WordSkipped>(), isEmpty);
    expect(events.whereType<WordRepeated>(), isEmpty);
    expect((events.whereType<CurrentWord>().last).ref, kursiRefs.last);
    // ignore: avoid_print
    print('Sample dev log:\n  ${log.take(3).join('\n  ')}\n  …\n  ${log.last}');
  });

  test('skipped word', () {
    final events = recite(kursi.replaceFirst('سنه ', ''));
    expect(refs<WordSkipped>(events), [refOf('سنه')]);
    expect(events.whereType<PossibleMistake>(), isEmpty);
    expect(refs<WordConfirmed>(events), hasLength(kursiRefs.length - 1));
  });

  test('repeated word', () {
    final events = recite(kursi.replaceFirst('الحي ', 'الحي الحي '));
    expect(refs<WordRepeated>(events), [refOf('الحي')]);
    expect(events.whereType<PossibleMistake>(), isEmpty);
    expect(refs<WordConfirmed>(events), kursiRefs);
  });

  test('extra words and hesitation fillers are ignored', () {
    final text = kursi
        .replaceFirst('الله ', 'الله امم ')
        .replaceFirst('يشفع ', 'يشفع اه اه ');
    final events = recite(text);
    expect(refs<WordConfirmed>(events), kursiRefs);
    expect(events.whereType<PossibleMistake>(), isEmpty);
    expect(events.whereType<WordSkipped>(), isEmpty);
  });

  test('short backtracking repeats the words, nothing else', () {
    final text = kursi.replaceFirst(
      'وما في الارض من',
      'وما في الارض ما في السماوات وما في الارض من',
    );
    final events = recite(text);
    expect(refs<WordConfirmed>(events), kursiRefs);
    expect(refs<WordRepeated>(events), [
      refOf('ما', nth: 1),
      refOf('في', nth: 1),
      refOf('السماوات', nth: 1),
      refOf('وما', nth: 1),
      refOf('في', nth: 2),
      refOf('الارض', nth: 1),
    ]);
    expect(events.whereType<PossibleMistake>(), isEmpty);
  });

  test('self-correction: a wrong word, then the right one', () {
    // «خلفنا» is close to «خلفهم» only — a word close to a *neighbour*
    // instead reads as going back to that neighbour.
    final text = kursi.replaceFirst('وما خلفهم', 'وما خلفنا وما خلفهم');
    final events = recite(text);
    final khalfahum = refOf('خلفهم');
    expect(refs<PossibleMistake>(events), [khalfahum]);
    final corrected = events.whereType<WordConfirmed>().where(
      (e) => e.corrected,
    );
    expect(corrected.map((e) => e.ref), [khalfahum]);
  });

  test('hesitation across repeated, unchanged partials adds nothing', () {
    final matcher = QuranStreamMatcher(corpus)..start(anchor: start);
    final events = <QuranMatchEvent>[
      for (var i = 0; i < 4; i++) ...matcher.onPartial('الله لا اله'),
      ...matcher.onPartial('الله لا اله الا'),
      for (var i = 0; i < 3; i++) ...matcher.onPartial('الله لا اله الا'),
      ...matcher.onFinal('الله لا اله الا هو'),
      ...matcher.flush(),
    ];
    expect(refs<WordConfirmed>(events), kursiRefs.take(5).toList());
  });

  test('a partial rewritten by the recognizer is not double-counted', () {
    final matcher = QuranStreamMatcher(corpus)..start(anchor: start);
    final events = <QuranMatchEvent>[
      ...matcher.onPartial('الله لا اله الا هو الحي'),
      ...matcher.onPartial('الله لا اله الا هو الحي القيوم لا'),
      ...matcher.onFinal('الله لا اله الا هو الحي القيوم لا تاخذه'),
      ...matcher.flush(),
    ];
    expect(refs<WordConfirmed>(events), kursiRefs.take(9).toList());
  });

  test('segments continue from where the previous one ended', () {
    final matcher = QuranStreamMatcher(corpus)..start(anchor: start);
    final words = kursi.split(' ');
    final events = [
      ...matcher.onFinal(words.take(20).join(' ')),
      ...matcher.onFinal(words.skip(20).join(' ')),
      ...matcher.flush(),
    ];
    expect(refs<WordConfirmed>(events), kursiRefs);
  });

  test('starting mid-page: found on the visible page', () {
    // The page shows 2:253–2:256; the reciter starts at 2:255.
    final pageStart = corpus.verseStartPosition((chapterNo: 2, verseNo: 253))!;
    final pageEnd = corpus.verseEndPosition((chapterNo: 2, verseNo: 256))!;
    final events = recite(
      kursi,
      anchor: pageStart,
      focus: (pageStart, pageEnd),
    );
    final relocated = events.whereType<MatchRelocated>().single;
    expect(relocated.scope, 'page');
    expect(relocated.to, kursiRefs.first);
    expect(refs<WordConfirmed>(events), kursiRefs);
  });

  test('reciting a different surah: found by searching the whole Quran', () {
    final events = recite(kursi, anchor: 0, focus: (0, 29));
    final relocated = events.whereType<MatchRelocated>().single;
    expect(relocated.scope, 'quran');
    expect(refs<WordConfirmed>(events), kursiRefs);
  });

  test('restarting the ayah from its beginning (a long jump back)', () {
    final words = kursi.split(' ');
    final text = [...words.take(25), ...words].join(' ');
    final events = recite(text);
    expect(refs<WordConfirmed>(events), kursiRefs);
    expect(refs<WordRepeated>(events), kursiRefs.take(25).toList());
    expect(events.whereType<PossibleMistake>(), isEmpty);
  });
}
