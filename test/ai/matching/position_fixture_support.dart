import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/ai/matching/local_quran_position_tracker.dart';
import 'package:tahfeez_ai/ai/matching/quran_phoneme_index.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/ai/matching/quran_word_corpus.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../acoustic/acoustic_test_support.dart';
import 'corpus_fixture.dart';

/// Another set (a held-out one) can be scored with
/// `TAHFEEZ_POSITION_FIXTURES=<dir>`.
final _dir =
    Platform.environment['TAHFEEZ_POSITION_FIXTURES'] ??
    'test/fixtures/acoustic/position';

PhonemeResources? _resources;

/// The real reference and whole-Quran index (built once per test run).
PhonemeResources loadTestPhonemes() => _resources ??= () {
  final corpus = loadTestCorpus();
  final reference = loadTestReference();
  return (
    reference: reference,
    index: QuranPhonemeIndex.build(reference, ayahStarts(corpus)),
  );
}();

List<(int, int)> ayahStarts(QuranWordCorpus corpus) => [
  for (var p = 0; p < corpus.length; p++)
    if (corpus.words[p].ref.wordIndex == 0) (corpus.words[p].ref.ayahId, p),
];

/// One recorded scenario (`tool/acoustic_verification/position_fixtures.py`):
/// real recitation streamed through the model as the app does.
class PositionScenario {
  PositionScenario(this.name, Map<String, Object?> json)
    : note = json['note']! as String,
      chunkEnds = (json['chunk_ends']! as List).cast<int>(),
      lastChunks = {...?(json['last_chunks'] as List?)?.cast<int>()},
      focus = (json['focus']! as List).cast<int>(),
      anchor = json['anchor']! as int,
      trustAnchor = json['trust_anchor']! as bool,
      recited = (json['recited']! as List).cast<int>();

  final String name, note;
  final List<int> chunkEnds;

  /// Chunks after which the audio paused (the pipeline flushed): the
  /// tracker flushes too. The final chunk always is one.
  final Set<int> lastChunks;

  /// First and last ayah id on screen.
  final List<int> focus;
  final int anchor;
  final bool trustAnchor;

  /// Ayah ids recited, in order.
  final List<int> recited;

  static Map<String, PositionScenario> all() {
    final json = jsonDecode(
      File('$_dir/scenarios.json').readAsStringSync(),
    ) as Map<String, Object?>;
    return {
      for (final MapEntry(:key, :value)
          in (json['scenarios']! as Map<String, Object?>).entries)
        key: PositionScenario(key, value! as Map<String, Object?>),
    };
  }

  AcousticFrames frames() {
    final raw = gzip.decode(File('$_dir/$name.f16.gz').readAsBytesSync());
    final half = ByteData.sublistView(Uint8List.fromList(raw));
    final out = Float32List(raw.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = _half(half.getUint16(i * 2, Endian.little));
    }
    return AcousticFrames(
      frames: out.length ~/ 43,
      classes: 43,
      logProbs: out,
      frameDuration: const Duration(milliseconds: 40),
    );
  }

  static double _half(int h) {
    final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
    final exp = (h >> 10) & 0x1f;
    final frac = h & 0x3ff;
    if (exp == 0) return sign * frac / 1024 * 6.103515625e-05;
    if (exp == 31) return frac == 0 ? sign * double.infinity : double.nan;
    return sign * (1 + frac / 1024) * _pow2(exp - 15);
  }

  static double _pow2(int e) {
    var v = 1.0;
    for (var i = 0; i < e.abs(); i++) {
      v *= 2;
    }
    return e < 0 ? 1 / v : v;
  }
}

/// What the tracker did over a scenario.
class ReplayResult {
  ReplayResult(this.scenario);

  final PositionScenario scenario;
  final events = <QuranMatchEvent>[];

  /// Per placed word: (corpus position, chunk end frame, word end frame).
  final placed = <(int, int, int)>[];
  int? locatedAtFrame;
  int? firstSpeechFrame;
  final verdicts = <HifzVerdict, int>{};
  final log = <String>[];

  Iterable<WordRef> get heard => events
      .whereType<WordHeard>()
      .where((h) => h.ref != null)
      .map((h) => h.ref!);
}

/// Replays [scenario] chunk by chunk (as the inference pipeline publishes
/// them) through a fresh tracker, and through a [HifzJudge] like the app.
ReplayResult replay(
  PositionScenario scenario, {
  LocalPositionTrackerConfig config = const LocalPositionTrackerConfig(),
}) {
  final corpus = loadTestCorpus();
  final resources = loadTestPhonemes();
  final result = ReplayResult(scenario);
  final tracker = LocalQuranPositionTracker(
    corpus,
    () => resources,
    config: config,
    log: result.log.add,
  );
  int pos(int ayahId, {bool last = false}) {
    final verse = (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000);
    return last
        ? corpus.verseEndPosition(verse)!
        : corpus.verseStartPosition(verse)!;
  }

  final anchor = pos(scenario.anchor);
  tracker
    ..start(anchor: anchor, trustAnchor: scenario.trustAnchor)
    ..setFocus(pos(scenario.focus[0]), pos(scenario.focus[1], last: true));
  HifzJudge? judge = scenario.trustAnchor
      ? HifzJudge(corpus, start: anchor, end: corpus.length - 1)
      : null;
  final frames = scenario.frames();
  var start = 0;
  for (final (i, chunkEnd) in scenario.chunkEnds.indexed) {
    // The final flush may count a partial frame the model did not output.
    final end = chunkEnd < frames.frames ? chunkEnd : frames.frames;
    if (end <= start) continue;
    final last =
        i == scenario.chunkEnds.length - 1 || scenario.lastChunks.contains(i);
    final chunk = TimedAcousticFrames(
      start,
      frames.slice(start, end - 1),
      last: last,
    );
    if (result.firstSpeechFrame == null) {
      for (var f = start; f < end; f++) {
        var best = 0;
        for (var c = 1; c < 43; c++) {
          if (frames.at(f, c) > frames.at(f, best)) best = c;
        }
        if (best != 0) {
          result.firstSpeechFrame = f;
          break;
        }
      }
    }
    final out = [...tracker.onFrames(chunk), if (last) ...tracker.flush()];
    if (result.locatedAtFrame == null && out.any((e) => e is MatchRelocated)) {
      result.locatedAtFrame = end;
    }
    for (final e in out.whereType<WordHeard>()) {
      if (e.ref == null) continue;
      result.placed.add((
        corpus.positionOf(e.ref!)!,
        end,
        tracker.lastPlacedFrame ?? end,
      ));
    }
    result.events.addAll(out);
    // Like HifzController: an unanchored test starts at the first word.
    for (final heard in out.whereType<WordHeard>()) {
      if (judge == null && heard.ref != null) {
        judge = HifzJudge(
          corpus,
          start: corpus.positionOf(heard.ref!)!,
          end: corpus.length - 1,
        );
      }
      for (final v in judge?.onHeard(heard) ?? const <HifzEvent>[]) {
        result.verdicts[v.verdict] = (result.verdicts[v.verdict] ?? 0) + 1;
      }
    }
    start = end;
  }
  return result;
}

/// Accuracy of a replay against what was recited.
class ReplayScore {
  factory ReplayScore.of(ReplayResult r) {
    final corpus = loadTestCorpus();
    final recitedWords = <int>{};
    for (final ayah in r.scenario.recited) {
      final verse = (chapterNo: ayah ~/ 1000, verseNo: ayah % 1000);
      for (
        var p = corpus.verseStartPosition(verse)!;
        p <= corpus.verseEndPosition(verse)!;
        p++
      ) {
        recitedWords.add(p);
      }
    }
    final placed = {for (final p in r.placed) p.$1};
    final wrong = r.placed.where((p) => !recitedWords.contains(p.$1)).length;
    // Follow latency: from a word's end to the end of the chunk that placed
    // it, plus the 1 s right context the window waited for.
    final lags = [
      for (final (_, chunkEnd, wordEnd) in r.placed)
        (chunkEnd - wordEnd + 25) * 0.04,
    ];
    return ReplayScore._(
      recited: recitedWords.length,
      placedWords: r.placed.length,
      correct: placed.intersection(recitedWords).length,
      wrong: wrong,
      relocations: r.events.whereType<MatchRelocated>().length,
      locateSeconds: r.locatedAtFrame == null || r.firstSpeechFrame == null
          ? null
          : (r.locatedAtFrame! + 25 - r.firstSpeechFrame!) * 0.04,
      meanFollowSeconds: lags.isEmpty
          ? null
          : lags.reduce((a, b) => a + b) / lags.length,
    );
  }

  ReplayScore._({
    required this.recited,
    required this.placedWords,
    required this.correct,
    required this.wrong,
    required this.relocations,
    required this.locateSeconds,
    required this.meanFollowSeconds,
  });

  /// Distinct words recited; placements made; distinct recited words
  /// placed; placements of words not recited.
  final int recited, placedWords, correct, wrong, relocations;
  final double? locateSeconds, meanFollowSeconds;

  int get unresolved => recited - correct;

  @override
  String toString() =>
      'recited $recited, placed $placedWords, correct $correct, '
      'wrong $wrong, unresolved $unresolved, relocations $relocations, '
      'locate ${locateSeconds?.toStringAsFixed(1) ?? '-'} s, follow '
      '${meanFollowSeconds?.toStringAsFixed(1) ?? '-'} s';
}
