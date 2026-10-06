import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/ai/matching/local_quran_position_tracker.dart';
import 'package:tahfeez_ai/ai/matching/quran_phoneme_index.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/ai/matching/recitation_position_matcher.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../acoustic/acoustic_test_support.dart';
import 'corpus_fixture.dart';
import 'position_fixture_support.dart';

/// Real recitation (4 reciters) streamed through the acoustic model as the
/// app streams it — `test/fixtures/acoustic/position`.
void main() {
  final corpus = loadTestCorpus();
  final scenarios = PositionScenario.all();
  final results = <String, (ReplayResult, ReplayScore)>{};

  (ReplayResult, ReplayScore) run(String name) => results[name] ??= () {
    final r = replay(scenarios[name]!);
    return (r, ReplayScore.of(r));
  }();

  int pos(int chapter, int verse, int word) =>
      corpus.positionOf((ayahId: chapter * 1000 + verse, wordIndex: word - 1))!;

  group('QuranPhonemeIndex', () {
    test('reduces symbol sequences: blanks, markers, repeats', () {
      final a = phoneticClassOf('ا'), b = phoneticClassOf('ب');
      final marker = phoneticClassOf('ڇ');
      expect(QuranPhonemeIndex.reduce([0, a, a, 0, a, marker, b, b]), [a, b]);
    });

    test('finds an ayah from its own expected pronunciation', () {
      final index = loadTestPhonemes().index;
      final kursi = [
        for (final t in loadTestReference().ayah(2255).take(40)) t.token,
      ];
      final found = index.lookup(QuranPhonemeIndex.reduce(kursi));
      expect(found, isNotEmpty);
      final at = pos(2, 255, 1);
      expect(found.first.firstWord, inInclusiveRange(at - 2, at + 2));
    });

    test('searches only the range asked for', () {
      final index = loadTestPhonemes().index;
      final kursi = QuranPhonemeIndex.reduce([
        for (final t in loadTestReference().ayah(2255).take(40)) t.token,
      ]);
      final limit = pos(2, 100, 1);
      final found = index.lookup(kursi, from: 0, to: limit);
      expect(found.every((c) => c.firstWord <= limit), isTrue);
      final whole = index.lookup(kursi);
      expect(whole.first.votes, greaterThan(found.first.votes * 3));
    });
  });

  group('LocalQuranPositionTracker on real recitation', () {
    test('never places a word that was not recited', () {
      for (final name in scenarios.keys) {
        expect(run(name).$2.wrong, 0, reason: '$name: ${run(name).$2}');
      }
    });

    test('follows a page from its start, word by word', () {
      final (r, score) = run('page_start');
      expect(score.unresolved, 0);
      expect(r.verdicts, {HifzVerdict.correct: 37});
      expect(r.events.whereType<MatchRelocated>().single.scope, 'page');
    });

    test('locates a start mid-ayah, and several ayahs into the page', () {
      final (r, mid) = run('mid_ayah');
      expect(r.heard.first, corpus.words[pos(36, 3, 3)].ref);
      expect(mid.unresolved, 2, reason: 'the words cut off');
      final (away, score) = run('ayahs_away');
      expect(away.heard.first, corpus.words[pos(36, 9, 1)].ref);
      expect(score.unresolved, 0);
    });

    test('relocates across the Quran when another page is recited', () {
      final (r, score) = run('wrong_page');
      final relocated = r.events.whereType<MatchRelocated>().single;
      expect(relocated.scope, 'quran');
      expect(relocated.to.ayahId, 18001);
      expect(score.unresolved, 0);
      expect(r.log, contains(startsWith('passed over 1:1:1')));
    });

    test('a repeated phrase stays unresolved until context decides', () {
      // 55:13 and 55:16 are word for word the same, on the same page.
      final (alone, score) = run('repeated_alone');
      expect(alone.heard, isEmpty);
      expect(score.placedWords, 0);
      expect(alone.log, contains(contains('ambiguous')));
      final (withContext, s2) = run('repeated_then_context');
      expect(withContext.heard.first.ayahId, 55013);
      expect(s2.unresolved, 0);
    });

    test('a skip, a repeat, a restart', () {
      final (skip, _) = run('skip');
      expect(skip.verdicts[HifzVerdict.skipped], 1);
      expect(skip.events.whereType<WordSkipped>().map((e) => e.ref.ayahId), {
        36003,
      });
      final (repeat, _) = run('repeat');
      expect(repeat.verdicts[HifzVerdict.repeated], 3);
      expect(repeat.verdicts[HifzVerdict.correct], 9);
      final (restart, _) = run('restart');
      expect(restart.verdicts[HifzVerdict.correct], 29);
      // The restart's basmala (1:1) is passed over as the opening formula
      // (madd now fits exactly, so it beats re-reading the words), then
      // 1:2 onwards repeats — none of it a mistake.
      expect(restart.verdicts[HifzVerdict.repeated], 8);
      expect(restart.log, contains(startsWith('passed over 1:1:1')));
      expect(restart.log, contains(startsWith('passed over 16:98:5')));
    });

    test('a false start then the right ayah reads as self-corrected', () {
      final (r, score) = run('self_correction');
      expect(r.verdicts[HifzVerdict.skipped], 1);
      expect(r.verdicts[HifzVerdict.selfCorrected], 1);
      expect(score.unresolved, 0);
    });

    test('long pauses and a fragment: followed, nothing invented', () {
      final (r, score) = run('hesitation');
      expect(score.unresolved, 0);
      expect(r.verdicts[HifzVerdict.correct], 15);
      expect(r.verdicts[HifzVerdict.repeated], isNull);
    });

    test('into the next page and surah', () {
      final (r, score) = run('page_transition');
      expect(score.unresolved, 0);
      expect(r.heard.map((w) => w.ayahId), containsAllInOrder([1007, 2001]));
    });

    test('a basmala between surahs is passed over, not a mistake', () {
      final (r, score) = run('surah_basmala');
      expect(score.unresolved, 0);
      expect(r.verdicts[HifzVerdict.skipped], isNull);
      expect(r.verdicts[HifzVerdict.wrong], isNull);
      expect(r.verdicts[HifzVerdict.selfCorrected], isNull);
      expect(r.verdicts[HifzVerdict.correct], 15 + 23);
    });

    test('a fragment that fits a short word further on is not a skip', () {
      // The tail of a basmala, heard as «مَا» (113:2:3) seven words ahead
      // of «قُلْ» (113:1:1): too little to believe the words between were
      // skipped.
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(113, 1, 1), trustAnchor: true);
      final ma = loadTestReference().words(113002, 2, 2);
      final frames = clearFrames([for (final t in ma) t.token]);
      final out = [
        ...tracker.onFrames(TimedAcousticFrames(0, frames)),
        ...tracker.flush(),
      ];
      expect(out.whereType<WordHeard>().where((h) => h.ref != null), isEmpty);
    });

    test('after a wrong word, the right one, a word back or a restart is '
        'followed', () {
      final ref = loadTestReference();
      List<int> said(int ayah, int from, int to) => [
        for (final t in ref.words(ayah, from, to)) t.token,
        ...List.filled(5, 0), // a short pause
      ];
      // 112:1 «قُلْ هُوَ», then «ٱلرَّحْمَٰنِ» instead of «ٱللَّهُ», then
      // on from the right word, from a word back, or from the ayah's start.
      for (final back in [2, 1, 0]) {
        final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
          ..start(anchor: pos(112, 1, 1), trustAnchor: true);
        final judge = HifzJudge(
          corpus,
          start: pos(112, 1, 1),
          end: corpus.length - 1,
        );
        final parts = [
          said(112001, 0, 1),
          said(1003, 0, 0),
          said(112001, back, 3),
        ];
        var at = 0;
        for (final (i, part) in parts.indexed) {
          final frames = clearFrames(part);
          final out = [
            ...tracker.onFrames(TimedAcousticFrames(at, frames)),
            if (i == parts.length - 1) ...tracker.flush(),
          ];
          at += frames.frames;
          for (final heard in out.whereType<WordHeard>()) {
            judge.onHeard(heard);
          }
        }
        expect(corpus.words[judge.expected].ref, (
          ayahId: 112002,
          wordIndex: 0,
        ), reason: 'resumed $back words into the ayah');
        expect(judge.counts[HifzVerdict.extra], greaterThanOrEqualTo(1));
      }
    });

    test('a word that begins as the last one ended is followed', () {
      // «إِلَّا ٱلَّذِينَ» (103:3) said joined: «ءِللَ للَذِۦنَ». The held end
      // of «إِلَّا» must not swallow the start of «ٱلَّذِينَ».
      final ref = loadTestReference();
      final span = ref.span([
        (ayahId: 103003, wordIndex: 0),
        (ayahId: 103003, wordIndex: 1),
        (ayahId: 103003, wordIndex: 2),
      ]);
      final joined = [
        for (final u in {for (final t in span.tokens) t.unit})
          ...span.pauses[u]?.apply(
                [
                  for (final t in span.tokens)
                    if (t.unit == u) t,
                ],
                stop: false,
                start: u == span.tokens.first.unit,
              ) ??
              [
                for (final t in span.tokens)
                  if (t.unit == u) t,
              ],
      ];
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(103, 3, 1), trustAnchor: true);
      final frames = clearFrames([
        for (final t in joined) t.token,
        ...List.filled(5, 0),
      ]);
      // As the stream delivers it: a few frames at a time.
      final out = <QuranMatchEvent>[];
      for (var at = 0; at < frames.frames; at += 4) {
        final to = math.min(frames.frames, at + 4);
        out.addAll(
          tracker.onFrames(TimedAcousticFrames(at, frames.slice(at, to - 1))),
        );
      }
      out.addAll(tracker.flush());
      final heard = out.whereType<WordHeard>().map((h) => h.ref).toList();
      expect(heard, [
        (ayahId: 103003, wordIndex: 0),
        (ayahId: 103003, wordIndex: 1),
        (ayahId: 103003, wordIndex: 2),
      ]);
    });

    test('going back to re-read the previous surah\'s last ayah is followed', () {
      // 106:4 (7 words), then into Al-Ma'un — «أَرَءَيْتَ ٱلَّذِى» — then back
      // to 106:4 from its start, 9 words back, and on into 107:1 again.
      final ref = loadTestReference();
      List<int> said(int ayah, int from, int to) => [
        for (final t in ref.words(ayah, from, to)) t.token,
        ...List.filled(6, 0),
      ];
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(106, 4, 1), trustAnchor: true);
      final parts = [
        said(106004, 0, 6),
        said(107001, 0, 1),
        said(106004, 0, 6),
        said(107001, 0, 3),
      ];
      final heard = <WordRef?>[];
      var at = 0;
      for (final (i, part) in parts.indexed) {
        final frames = clearFrames(part);
        for (var f = 0; f < frames.frames; f += 4) {
          final to = math.min(frames.frames, f + 4);
          heard.addAll(
            tracker
                .onFrames(TimedAcousticFrames(at + f, frames.slice(f, to - 1)))
                .whereType<WordHeard>()
                .map((h) => h.ref),
          );
        }
        at += frames.frames;
        if (i == parts.length - 1) {
          heard.addAll(
            tracker.flush().whereType<WordHeard>().map((h) => h.ref),
          );
        }
      }
      // 106:4 heard twice, and 107:1 through to its last word.
      expect(
        heard.where((r) => r == (ayahId: 106004, wordIndex: 0)),
        hasLength(2),
      );
      expect(heard.last, (ayahId: 107001, wordIndex: 3));
    });

    test('noise is never placed', () {
      final (r, _) = run('not_quran');
      expect(r.events, isEmpty);
    });

    test('follow latency stays near the 2 s hop + 1 s context', () {
      for (final name in scenarios.keys) {
        final follow = run(name).$2.meanFollowSeconds;
        if (follow != null) expect(follow, lessThan(3.0), reason: name);
      }
    });
  });

  group('LocalQuranPositionTracker contract', () {
    test('is a RecitationPositionMatcher', () {
      expect(
        LocalQuranPositionTracker(corpus, () => null),
        isA<RecitationPositionMatcher>(),
      );
    });

    test('without its resources yet, places nothing and keeps up', () {
      final tracker = LocalQuranPositionTracker(corpus, () => null)
        ..start(anchor: 0, trustAnchor: true);
      final frames = scenarios['page_start']!.frames();
      for (var at = 0; at + 50 <= 400; at += 50) {
        expect(
          tracker.onFrames(TimedAcousticFrames(at, frames.slice(at, at + 49))),
          isEmpty,
        );
      }
      expect(tracker.flush(), isEmpty);
    });

    test('the same frames in other chunk sizes place the same words', () {
      final s = scenarios['page_start']!;
      final frames = s.frames();
      final resources = loadTestPhonemes();
      List<String> words(int chunk) {
        final tracker = LocalQuranPositionTracker(corpus, () => resources)
          ..start(anchor: pos(36, 1, 1), trustAnchor: true);
        final out = <QuranMatchEvent>[];
        for (var at = 0; at < frames.frames; at += chunk) {
          final end = (at + chunk).clamp(0, frames.frames);
          out.addAll(
            tracker.onFrames(
              TimedAcousticFrames(at, frames.slice(at, end - 1)),
            ),
          );
        }
        out.addAll(tracker.flush());
        return [
          for (final h in out.whereType<WordHeard>())
            if (h.ref != null) '${h.ref}',
        ];
      }

      final reference = words(50);
      expect(reference, hasLength(37));
      expect(words(75), reference);
      expect(words(150), reference);
    });
  });
}
