// Accuracy of QuranStreamMatcher on real speech-recognition output:
// test/fixtures/asr/*.json hold the partial/final transcripts Chrome's Web
// Speech API produced for Mishary Alafasy's recitation of each passage (see
// each file's `source`). The recitation is perfect, so every canonical word
// of the passage should be confirmed, nothing outside it, and no mistakes
// or skips flagged.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/ai/matching/quran_word_corpus.dart';

import 'corpus_fixture.dart';

typedef Passage = List<({int chapter, int from, int to})>;

const passages = <String, Passage>{
  'fatiha_1_1-7': [(chapter: 1, from: 1, to: 7)],
  'baqara_2_1-5': [(chapter: 2, from: 1, to: 5)],
  'kursi_2_255': [(chapter: 2, from: 255, to: 255)],
  'kahf_18_1-5': [(chapter: 18, from: 1, to: 5)],
  'yasin_36_1-12': [(chapter: 36, from: 1, to: 12)],
  'rahman_55_1-16': [(chapter: 55, from: 1, to: 16)],
  'mulk_67_1-5': [(chapter: 67, from: 1, to: 5)],
  'qul_112-114': [
    (chapter: 112, from: 1, to: 4),
    (chapter: 113, from: 1, to: 5),
    (chapter: 114, from: 1, to: 6),
  ],
};

class RunResult {
  RunResult(this.name, this.expected, this.events);
  final String name;
  final Set<int> expected;
  final List<(QuranMatchEvent, int?)> events; // event, corpus position

  Set<int> get confirmed => {
    for (final (e, p) in events)
      if (e is WordConfirmed) p!,
  };
  double get recall =>
      confirmed.intersection(expected).length / expected.length;
  int get outside => confirmed.difference(expected).length;
  int get mistakes => events.where((e) => e.$1 is PossibleMistake).length;
  int get skips => events.where((e) => e.$1 is WordSkipped).length;
  int get relocations => events.where((e) => e.$1 is MatchRelocated).length;
  int? get lastCurrent => events
      .lastWhere(
        (e) => e.$1 is CurrentWord,
        orElse: () => (const WordSkipped((ayahId: 0, wordIndex: 0)), null),
      )
      .$2;
}

Set<int> expectedPositions(QuranWordCorpus corpus, Passage passage) => {
  for (final p in passage)
    for (var v = p.from; v <= p.to; v++)
      for (
        var i = corpus.verseStartPosition((chapterNo: p.chapter, verseNo: v))!;
        i <= corpus.verseEndPosition((chapterNo: p.chapter, verseNo: v))!;
        i++
      )
        i,
};

RunResult run(
  QuranWordCorpus corpus,
  String name, {
  required int anchor,
  required int focusStart,
  required int focusEnd,
  List<String>? log,
}) {
  final file = File('test/fixtures/asr/$name.chrome.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final matcher = QuranStreamMatcher(corpus, log: log?.add)
    ..start(anchor: anchor)
    ..setFocus(focusStart, focusEnd);
  int? pos(QuranMatchEvent e) => switch (e) {
    CurrentWord(:final ref) ||
    WordConfirmed(:final ref) ||
    WordSkipped(:final ref) ||
    WordRepeated(:final ref) ||
    PossibleMistake(:final ref) => corpus.positionOf(ref),
    MatchRelocated(:final to) => corpus.positionOf(to),
    WordHeard(:final ref) => ref == null ? null : corpus.positionOf(ref),
  };
  final events = <(QuranMatchEvent, int?)>[];
  for (final e in (data['events']! as List).cast<Map<String, Object?>>()) {
    final text = e['text']! as String;
    final out = switch (e['type']) {
      'partial' => matcher.onPartial(text),
      'final' => matcher.onFinal(text),
      _ => const <QuranMatchEvent>[],
    };
    events.addAll(out.map((x) => (x, pos(x))));
  }
  // Recitation stopped: emit the word held back from the last final.
  events.addAll(matcher.flush().map((x) => (x, pos(x))));
  return RunResult(name, expectedPositions(corpus, passages[name]!), events);
}

void main() {
  final corpus = loadTestCorpus();

  void report(String title, List<RunResult> results) {
    final lines = <String>[title];
    var hit = 0, total = 0;
    for (final r in results) {
      hit += r.confirmed.intersection(r.expected).length;
      total += r.expected.length;
      final end = r.expected.reduce((a, b) => a > b ? a : b);
      lines.add(
        '  ${r.name.padRight(16)} words ${r.expected.length.toString().padLeft(3)}'
        '  recall ${(r.recall * 100).toStringAsFixed(1).padLeft(5)}%'
        '  outside ${r.outside}  mistakes ${r.mistakes}  skips ${r.skips}'
        '  relocations ${r.relocations}  end off by ${(r.lastCurrent ?? -999) - end}',
      );
    }
    lines.add(
      '  TOTAL recall ${(hit / total * 100).toStringAsFixed(1)}% ($hit/$total)',
    );
    // ignore: avoid_print
    print(lines.join('\n'));
  }

  test('recitation starting on the visible page', () {
    final results = [
      for (final name in passages.keys)
        () {
          final expected = expectedPositions(corpus, passages[name]!);
          final first = expected.reduce((a, b) => a < b ? a : b);
          final last = expected.reduce((a, b) => a > b ? a : b);
          // The visible page begins a little before the recited passage.
          final pageStart = (first - 12).clamp(0, corpus.length);
          return run(
            corpus,
            name,
            anchor: pageStart,
            focusStart: pageStart,
            focusEnd: last + 40,
          );
        }(),
    ];
    report('Visible page = the recited page', results);
    for (final r in results) {
      expect(r.recall, greaterThanOrEqualTo(0.9), reason: r.name);
      expect(r.outside, lessThanOrEqualTo(2), reason: r.name);
    }
  });

  test('recitation elsewhere than the visible page (global search)', () {
    final results = [
      for (final name in passages.keys)
        // Al-Fātiḥah on screen, reciting something else (and vice versa).
        name == 'fatiha_1_1-7'
            ? run(
                corpus,
                name,
                anchor: 60000,
                focusStart: 60000,
                focusEnd: 60150,
              )
            : run(corpus, name, anchor: 0, focusStart: 0, focusEnd: 29),
    ];
    report('Visible page = somewhere else', results);
    for (final r in results) {
      expect(r.recall, greaterThanOrEqualTo(0.85), reason: r.name);
      expect(r.relocations, greaterThanOrEqualTo(1), reason: r.name);
    }
  });
}
