import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
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

    test('an ayah\'s last words, the short ones before its last heard as '
        'silence, are placed at the pause', () {
      // Owner's phone, 2:8: «…وَبِٱلْيَوْمِ ٱلْءَاخِرِ وَمَا هُم بِمُؤْمِنِينَ» with
      // «وَمَا هُم» said aloud but heard mostly as blanks, then a pause. They
      // were shown only once the next ayah was said (5.8 s late).
      final ref = loadTestReference();
      final classes = quranPhoneticVocabulary.length;
      final rows = <List<double>>[];
      void frame(int top, [int? second]) => rows.add([
        for (var k = 0; k < classes; k++)
          k == top ? -0.1 : (k == second ? -2.5 : -20),
      ]);
      frame(ctcBlank);
      // The ayah as said (its joined units), «وَمَا هُم» (words 9 and 10)
      // blanks with their sounds only second.
      final span = ref.span([
        for (var w = 0; w < 11; w++) (ayahId: 2008, wordIndex: w),
      ]);
      for (final t in span.tokens) {
        if (t.optional || t.unitFinalVowel) continue;
        final weak = t.word.wordIndex == 8 || t.word.wordIndex == 9;
        frame(weak ? ctcBlank : t.token, weak ? t.token : null);
        frame(weak ? ctcBlank : t.token, weak ? t.token : null);
        frame(ctcBlank);
      }
      for (var i = 0; i < 30; i++) {
        frame(ctcBlank);
      }
      final frames = AcousticFrames(
        frames: rows.length,
        classes: classes,
        logProbs: Float32List.fromList([for (final r in rows) ...r]),
        frameDuration: const Duration(milliseconds: 40),
      );
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(2, 8, 1), trustAnchor: true);
      final out = <QuranMatchEvent>[];
      for (var at = 0; at < frames.frames; at += 4) {
        final to = math.min(frames.frames, at + 4);
        out.addAll(
          tracker.onFrames(TimedAcousticFrames(at, frames.slice(at, to - 1))),
        );
      }
      // The pause: what was held back is final now.
      out.addAll(tracker.flush());
      final heard = out.whereType<WordHeard>().map((h) => h.ref).toList();
      expect(heard, [
        for (var w = 0; w < 11; w++) (ayahId: 2008, wordIndex: w),
      ]);
    });

    test('a stop at a waqf sign, its end heard as sound, does not hold the '
        'next words', () {
      // Owner's phone, 14:22: «…فَٱسْتَجَبْتُمْ لِى ۖ» stopped at the waqf
      // sign, its end heard as «ۦهه», then «فَلَا تَلُومُونِى…». The stop was
      // taken for «لِى» said again and the next words were shown 10 s late.
      final ref = loadTestReference();
      final classes = quranPhoneticVocabulary.length;
      final rows = <List<double>>[];
      void frame(int top) =>
          rows.add([for (var k = 0; k < classes; k++) k == top ? 0 : -20]);
      void say(int from, int to) {
        final span = ref.span([
          for (var w = from; w <= to; w++) (ayahId: 14022, wordIndex: w),
        ]);
        for (final t in span.tokens) {
          if (t.optional || t.unitFinalVowel) continue;
          frame(t.token);
          frame(t.token);
          frame(ctcBlank);
        }
      }

      frame(ctcBlank);
      say(18, 22); // … «فَٱسْتَجَبْتُمْ لِى»
      for (final c in ['ۦ', 'ه', 'ه']) {
        frame(phoneticClassOf(c));
      }
      for (var i = 0; i < 30; i++) {
        frame(ctcBlank);
      }
      say(23, 27); // «فَلَا تَلُومُونِى وَلُومُوٓا۟ أَنفُسَكُم»
      for (var i = 0; i < 6; i++) {
        frame(ctcBlank);
      }
      final frames = AcousticFrames(
        frames: rows.length,
        classes: classes,
        logProbs: Float32List.fromList([for (final r in rows) ...r]),
        frameDuration: const Duration(milliseconds: 40),
      );
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(14, 22, 19), trustAnchor: true);
      final out = <QuranMatchEvent>[];
      for (var at = 0; at < frames.frames; at += 4) {
        final to = math.min(frames.frames, at + 4);
        out.addAll(
          tracker.onFrames(TimedAcousticFrames(at, frames.slice(at, to - 1))),
        );
      }
      // Before any pause: the words after the stop are followed as said.
      final heard = out.whereType<WordHeard>().map((h) => h.ref).toList();
      expect(heard, contains((ayahId: 14022, wordIndex: 24)));
      expect(
        heard.where((r) => r == (ayahId: 14022, wordIndex: 22)),
        hasLength(1),
      );
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

    test('going back to words found in several places waits for the next '
        'word', () {
      // 2:14 up to «شَيَٰطِينِهِمْ», then back to «وَإِذَا خَلَوْا۟» (its 7th word)
      // to say it again. «وَإِذَا» alone also opens 2:13 and 2:14: only
      // «خَلَوْا۟» after it says which — not 2:13's start.
      final ref = loadTestReference();
      List<int> said(int ayah, int from, int to) => [
        for (final t in ref.words(ayah, from, to)) t.token,
        ...List.filled(6, 0),
      ];
      final tracker = LocalQuranPositionTracker(corpus, loadTestPhonemes)
        ..start(anchor: pos(2, 14, 1), trustAnchor: true);
      // A pause after «وَإِذَا» (the app flushes the tracker there).
      final parts = [said(2014, 0, 9), said(2014, 6, 6), said(2014, 7, 11)];
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
        if (i > 0) {
          heard.addAll(
            tracker.flush().whereType<WordHeard>().map((h) => h.ref),
          );
        }
      }
      expect(heard.where((r) => r?.ayahId == 2013), isEmpty);
      expect(
        heard.where((r) => r == (ayahId: 2014, wordIndex: 7)),
        hasLength(2),
        reason: '«خَلَوْا۟» said twice',
      );
      expect(heard.last, (ayahId: 2014, wordIndex: 11));
    });

    test('noise is never placed', () {
      final (r, _) = run('not_quran');
      expect(r.events, isEmpty);
    });

    test('other speech uncovers none of the surah the test starts at', () {
      // Al-Fatiha's test started, then other surahs recited: their «…ِيم»
      // endings passed for «ٱلرَّحِيمِ», «يسٓ» or «…أَحَدٌ ٱللَّهُ» for
      // «بِسْمِ ٱللَّهِ» — and the ayah uncovered (owner, 2026-11-02, with
      // English speech). Each is located where it really is instead.
      for (final name in [
        'page_start',
        'mid_ayah',
        'ayahs_away',
        'repeated_then_context',
        'repeated_alone',
        'skip',
        'repeat',
        'self_correction',
        'hesitation',
      ]) {
        final s = scenarios[name]!;
        final r = replay(
          PositionScenario(name, {
            'note': s.note,
            'chunk_ends': s.chunkEnds,
            'last_chunks': s.lastChunks.toList(),
            'focus': [1001, 1007],
            'anchor': 1001,
            'trust_anchor': true,
            'recited': s.recited,
          }),
        );
        expect(
          r.heard.where((w) => w.ayahId < 2000),
          isEmpty,
          reason: '$name: ${r.log.take(6).join(' / ')}',
        );
        expect(r.verdicts[HifzVerdict.correct], isNull, reason: name);
      }
    });

    test('after other speech, the expected word is heard as soon as said', () {
      // Al-Fatiha's basmala, then other speech (Ya-Sin standing in for the
      // English the owner played, 2026-11-02), then «ٱلْحَمْدُ لِلَّهِ…».
      // A «…ِين» in it once passed for «ٱلدِّينِ» eight words on, and the
      // ayah said next was taken for going back: not heard at all.
      final fatiha = scenarios['restart']!.frames();
      final yasin = scenarios['page_start']!.frames();
      for (final other in [40, 150, 250]) {
        final frames = joinFrames([
          (fatiha, 0, 245),
          (yasin, 10, 10 + other - 1),
          (fatiha, 246, 560),
        ]);
        final r = replay(
          PositionScenario('restart', {
            'note': '',
            'chunk_ends': [
              for (var e = 50; e < frames.frames; e += 50) e,
              frames.frames,
            ],
            'focus': [1001, 1007],
            'anchor': 1001,
            'trust_anchor': true,
            'recited': <int>[],
          }),
          frames: frames,
        );
        // «ٱلْحَمْدُ» ends 281 frames in, without the other speech: placed
        // at the end of the chunk it ends in.
        final said = 281 + other;
        final alhamdu = pos(1, 2, 1);
        expect(r.placed.where((p) => p.$1 == alhamdu).map((p) => p.$2), [
          (said ~/ 50 + 1) * 50,
        ], reason: '$other frames: ${r.log.join(' / ')}');
        expect(r.verdicts[HifzVerdict.skipped], isNull, reason: '$other');
      }
    });

    test('a word said one ahead goes there, not to the same words further '
        'back', () {
      // «ٱلرَّحْمَٰنِ» left out after «ٱلْعَٰلَمِينَ»: «ٱلرَّحِيمِ» is 1:3:2,
      // not the basmala's, six words back (as «ٱلَّذِينَ» after 4:75's
      // «وَٱلنِّسَآءِ» was taken for 4:74's, owner 2026-11-02).
      final fatiha = scenarios['restart']!.frames();
      final frames = joinFrames([(fatiha, 0, 371), (fatiha, 403, 560)]);
      final r = replay(
        PositionScenario('restart', {
          'note': '',
          'chunk_ends': [
            for (var e = 32; e < frames.frames; e += 32) e,
            frames.frames,
          ],
          'focus': [1001, 1007],
          'anchor': 1001,
          'trust_anchor': true,
          'recited': <int>[],
        }),
        frames: frames,
      );
      final order = [for (final p in r.placed) p.$1];
      final after = order.sublist(order.indexOf(pos(1, 2, 4)) + 1);
      expect(after.first, pos(1, 3, 2), reason: r.log.join(' / '));
      expect(after, isNot(contains(pos(1, 1, 4))));
    });

    test('a word is not placed over far more audio than it takes', () {
      // English during 1:3 was stretched over 6.8 s as «ٱلرَّحْمَٰنِ», then
      // 1:3 itself taken for the basmala's same words (owner, 2026-11-02).
      // Here 1:3:1's own frames, each held 8 times as long.
      final fatiha = scenarios['restart']!.frames();
      final frames = joinFrames([
        (fatiha, 0, 360),
        for (var f = 361; f <= 404; f++)
          for (var i = 0; i < 8; i++) (fatiha, f, f),
        (fatiha, 405, 470),
      ]);
      final r = replay(
        PositionScenario('restart', {
          'note': '',
          'chunk_ends': [
            for (var e = 32; e < frames.frames; e += 32) e,
            frames.frames,
          ],
          'focus': [1001, 1007],
          'anchor': 1001,
          'trust_anchor': true,
          'recited': <int>[],
        }),
        frames: frames,
      );
      expect(r.log, contains(startsWith('too long for 1:3:1')));
      expect(
        r.placed.map((p) => p.$1),
        isNot(contains(pos(1, 3, 1))),
        reason: r.log.join(' / '),
      );
    });

    group('the isti\'adha and the basmala are passed over', () {
      // The reciters' own: 'restart' opens with the isti'adha (frames
      // 0–133) and Al-Fatiha's basmala (134–240); 'page_start' is Ya-Sin.
      ReplayResult yasinWith(
        List<(AcousticFrames, int, int)> parts, {
        int from = 36001,
        bool trusted = false,
      }) {
        final frames = joinFrames(parts);
        return replay(
          PositionScenario('page_start', {
            'note': '',
            'chunk_ends': [
              for (var e = 32; e < frames.frames; e += 32) e,
              frames.frames,
            ],
            'focus': [from, 36012],
            'anchor': from,
            'trust_anchor': trusted,
            'focus_only': true,
            'recited': <int>[],
          }),
          frames: frames,
        );
      }

      test('before the page on screen, searched alone', () {
        // Searching the page only, the basmala was not found as one: fitted
        // as the page before's «بِهِۦ جَمْعًا», it held the reciter 8 s and
        // dropped «إِنَّ» (page 600, owner 2026-11-02).
        final fatiha = scenarios['restart']!.frames();
        final yasin = scenarios['page_start']!.frames();
        for (final (name, upTo) in [('isti\'adha', 133), ('both', 240)]) {
          final r = yasinWith([(fatiha, 0, upTo), (yasin, 0, 560)]);
          final log = r.log.join(' / ');
          expect(r.log, contains(startsWith('passed over 16:98:5')));
          if (upTo == 240) {
            expect(r.log, contains(startsWith('passed over 1:1:1')));
          }
          expect(r.placed.first.$1, pos(36, 1, 1), reason: '$name: $log');
          // «يسٓ» ends 97 frames into Ya-Sin: placed within a chunk or two.
          expect(
            r.placed.first.$2,
            lessThanOrEqualTo(upTo + 1 + 97 + 64),
            reason: '$name: $log',
          );
          expect(r.verdicts.keys, [HifzVerdict.correct], reason: name);
        }
      });

      test('between ayahs, in the middle of a recitation', () {
        // A basmala comes in 1.28 s chunks: «بِسْمِ ٱللَّهِ» alone was
        // set aside as other speech, and «…ٱلرَّحِيمِ» then taken for words.
        final fatiha = scenarios['restart']!.frames();
        final yasin = scenarios['page_start']!.frames();
        for (final (name, a, b, formula) in [
          ('basmala', 134, 240, '1:1:1'),
          ('isti\'adha', 0, 133, '16:98:5'),
        ]) {
          final r = yasinWith([
            (yasin, 0, 390),
            (fatiha, a, b),
            (yasin, 391, 700),
          ], trusted: true);
          expect(
            r.log,
            contains(startsWith('passed over $formula')),
            reason: name,
          );
          expect(r.verdicts.keys, [
            HifzVerdict.correct,
          ], reason: '$name: ${r.log.join(' / ')}');
          expect(r.placed.map((p) => p.$1), contains(pos(36, 5, 2)));
        }
      });

      test('except in Al-Fatiha, where it is the first ayah', () {
        final fatiha = scenarios['restart']!.frames();
        final frames = joinFrames([(fatiha, 134, 560)]);
        final r = replay(
          PositionScenario('restart', {
            'note': '',
            'chunk_ends': [
              for (var e = 32; e < frames.frames; e += 32) e,
              frames.frames,
            ],
            'focus': [1001, 1007],
            'anchor': 1001,
            'trust_anchor': false,
            'focus_only': true,
            'recited': <int>[],
          }),
          frames: frames,
        );
        expect(r.log, isNot(contains(startsWith('passed over 1:1:1'))));
        expect(
          [for (final p in r.placed.take(4)) p.$1],
          [for (var w = 1; w <= 4; w++) pos(1, 1, w)],
        );
      });
    });

    test('searching the page on screen, nothing off it is placed', () {
      // The fit around a word found was widened 3 words each way, past the
      // page's edge. Here the page "starts" at 36:2: «يسٓ» before it.
      final r = replay(
        PositionScenario('page_start', {
          'note': '',
          'chunk_ends': scenarios['page_start']!.chunkEnds,
          'focus': [36002, 36012],
          'anchor': 36002,
          'trust_anchor': false,
          'focus_only': true,
          'recited': <int>[],
        }),
      );
      expect(r.placed.first.$1, pos(36, 2, 1), reason: r.log.join(' / '));
      expect(r.placed.where((p) => p.$1 < pos(36, 2, 1)), isEmpty);
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
