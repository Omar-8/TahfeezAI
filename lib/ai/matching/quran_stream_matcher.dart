import 'dart:math' as math;
import 'dart:typed_data';

import '../../quran/domain/models/quran_refs.dart';
import 'quran_match_normalizer.dart';
import 'quran_word_corpus.dart';
import 'recitation_position_matcher.dart';

/// What the matcher concluded about the recitation, in canonical
/// [WordRef]s. Diagnostic signals only — no scoring is kept from them yet.
sealed class QuranMatchEvent {
  const QuranMatchEvent();
}

/// One recognized word, as aligned: the canonical word it landed on
/// ([ref] `null` when it matched nothing — an extra word such as a
/// hesitation filler), what was heard, and how similar the two are.
/// Emitted for every word once it is stable, before the verdict events
/// below; consumers with their own rules (Hifz mode) judge from these.
class WordHeard extends QuranMatchEvent {
  const WordHeard({
    required this.ref,
    required this.heard,
    required this.similarity,
    this.provisional = false,
  });
  final WordRef? ref;
  final String heard;
  final double similarity;

  /// The word still being heard — the last one of a partial (or held from
  /// a final), which the recognizer may yet revise. Reported so a consumer
  /// can react to the word just said without waiting for the next one; the
  /// same word is reported again, non-provisionally, once it is stable.
  final bool provisional;
  @override
  String toString() =>
      'WordHeard(${ref == null ? 'extra' : _fmt(ref!)}, "$heard", '
      '${similarity.toStringAsFixed(2)}${provisional ? ', provisional' : ''})';
}

/// Where the reciter is now (the latest matched word).
class CurrentWord extends QuranMatchEvent {
  const CurrentWord(this.ref, {required this.confidence});
  final WordRef ref;
  final double confidence;
  @override
  String toString() =>
      'CurrentWord(${_fmt(ref)}, ${confidence.toStringAsFixed(2)})';
}

/// A word recited as written. [corrected]: it was first recited wrongly
/// and the reciter went back and said it again correctly.
class WordConfirmed extends QuranMatchEvent {
  const WordConfirmed(
    this.ref, {
    required this.similarity,
    this.corrected = false,
  });
  final WordRef ref;
  final double similarity;
  final bool corrected;
  @override
  String toString() =>
      'WordConfirmed(${_fmt(ref)}${corrected ? ', corrected' : ''})';
}

/// A word passed over between two recited words.
class WordSkipped extends QuranMatchEvent {
  const WordSkipped(this.ref);
  final WordRef ref;
  @override
  String toString() => 'WordSkipped(${_fmt(ref)})';
}

/// A word already recited, said again (repetition or going back).
class WordRepeated extends QuranMatchEvent {
  const WordRepeated(this.ref);
  final WordRef ref;
  @override
  String toString() => 'WordRepeated(${_fmt(ref)})';
}

/// Something was recited in this word's place that doesn't match it well.
/// Recognition errors look the same, so this is only a *possible* mistake.
class PossibleMistake extends QuranMatchEvent {
  const PossibleMistake(
    this.ref, {
    required this.heard,
    required this.similarity,
  });
  final WordRef ref;
  final String heard;
  final double similarity;
  @override
  String toString() => 'PossibleMistake(${_fmt(ref)}, heard "$heard")';
}

/// The matcher found the reciter somewhere other than where it expected
/// (a new starting point, a jump, or a restart far back).
class MatchRelocated extends QuranMatchEvent {
  const MatchRelocated({
    required this.from,
    required this.to,
    required this.scope,
  });
  final WordRef? from;
  final WordRef to;

  /// Which search area found it: `page`, `nearby` or `quran`.
  final String scope;
  @override
  String toString() =>
      'MatchRelocated(${from == null ? '-' : _fmt(from!)} → ${_fmt(to)}, $scope)';
}

String _fmt(WordRef r) =>
    '${r.ayahId ~/ 1000}:${r.ayahId % 1000}:${r.wordIndex + 1}';

/// Tunables for [QuranStreamMatcher]. Scores are in "log-odds-ish" units:
/// a perfect word match earns +1.
class QuranMatcherConfig {
  const QuranMatcherConfig({
    this.maxSkip = 6,
    this.maxBack = 8,
    this.skipCost = 0.7,
    this.repeatCost = 0.35,
    this.backCost = 0.5,
    this.extraCost = 0.45,
    this.maxRestart = 60,
    this.restartCost = 1.2,
    this.confirmSimilarity = 0.72,
    this.minRelocateWords = 3,
  });

  /// Words that may be skipped between two recited words.
  final int maxSkip;

  /// How far back the reciter may jump within the current area.
  final int maxBack;
  final double skipCost, repeatCost, backCost, extraCost;

  /// Restarting from the beginning of an ayah up to this many words back —
  /// the common long backtrack — costs [restartCost], wherever it lands.
  final int maxRestart;
  final double restartCost;

  /// Similarity at or above which a word counts as recited correctly.
  final double confirmSimilarity;

  /// Recognized words needed before searching outside the current area.
  final int minRelocateWords;
}

enum _OpKind { match, extra, mergedFirst, merged }

class _Op {
  const _Op(this.kind, [this.position = -1, this.similarity = 0]);
  final _OpKind kind;
  final int position;
  final double similarity;
}

class _Alignment {
  const _Alignment(this.ops, this.score, this.anchor);
  final List<_Op> ops;
  final double score;
  final int anchor;

  Iterable<_Op> get matches =>
      ops.where((o) => o.kind == _OpKind.match || o.kind == _OpKind.merged);

  int get good => matches.where((o) => o.similarity >= 0.75).length;

  /// Share of recognized words that matched well.
  double get quality => ops.isEmpty ? 0 : good / ops.length;

  int? get lastPosition {
    for (final o in ops.reversed) {
      if (o.kind == _OpKind.match || o.kind == _OpKind.merged) {
        return o.position;
      }
    }
    return null;
  }
}

/// Turns a stream of recognition transcripts into canonical Quran word
/// positions.
///
/// Recognition arrives as *segments*: repeated partial transcripts (each
/// replacing the last) and then a final one. Every update re-aligns the
/// whole segment against a moving window of canonical words starting at
/// the current position, with a Viterbi search that allows normal
/// progression, skipped words, repeated words, short jumps back
/// (backtracking / self-correction), extra words (hesitation fillers,
/// recognition noise) and two recognized words standing for one Uthmani
/// word («يا ايها» → «يَٰٓأَيُّهَا»). Events are emitted once per recognized
/// word, when it can no longer change (every word of a partial except the
/// last, and everything in a final).
///
/// If the segment clearly doesn't fit the current area, the search expands:
/// the visible page first ([setFocus]), then nearby, then the whole Quran.
class QuranStreamMatcher implements RecitationPositionMatcher {
  QuranStreamMatcher(
    this.corpus, {
    this.config = const QuranMatcherConfig(),
    this.log,
    QuranMatchNormalizer normalizer = const QuranMatchNormalizer(),
  }) : _n = normalizer;

  final QuranWordCorpus corpus;
  final QuranMatcherConfig config;

  /// Development log sink: one line per update (recognized text → matched
  /// words → current word → confidence).
  final void Function(String line)? log;
  final QuranMatchNormalizer _n;

  int? _cursor; // next expected position (a hint until [_locked])
  int _focusStart = 0, _focusEnd = 0;
  bool _hasFocus = false;

  /// Whether the reciter's position has been established. Until then the
  /// starting point is only a hint, and nothing is emitted: the opening
  /// words of many ayahs recur elsewhere (Āyat al-Kursī's «الله لا اله الا
  /// هو», Al-Kahf's «الحمد لله الذي»), so the matcher waits for enough words
  /// to tell the candidates apart.
  bool _locked = false;

  int? _segmentAnchor; // anchor chosen (possibly relocated) for this segment
  int _segmentEmitted = 0;
  int _confirmedMax = -1;
  final Set<int> _mistakes = {};
  int? _current;
  final List<double> _recent = [];

  WordRef? get current => _current == null ? null : corpus.words[_current!].ref;

  /// Rolling confidence (0–1) in the current position.
  double get confidence =>
      _recent.isEmpty ? 0 : _recent.reduce((a, b) => a + b) / _recent.length;

  /// Where recitation is expected to begin — typically the first word of
  /// the visible page. A hint, not a commitment, unless [trustAnchor]:
  /// then recitation is known to start exactly there (Hifz mode's range).
  /// Resets all session state.
  @override
  void start({int? anchor, bool trustAnchor = false}) {
    _cursor = anchor;
    _locked = trustAnchor && anchor != null;
    _segmentAnchor = null;
    _segmentEmitted = 0;
    _confirmedMax = -1;
    _mistakes.clear();
    _current = null;
    _recent.clear();
  }

  /// The positions shown on screen: searched first when locating.
  @override
  void setFocus(int start, int end) {
    _focusStart = start;
    _focusEnd = end;
    _hasFocus = true;
  }

  List<QuranMatchEvent> onPartial(String transcript) =>
      _process(transcript, isFinal: false);

  List<QuranMatchEvent> onFinal(String transcript) =>
      _process(transcript, isFinal: true);

  /// Emits what is still held back — the last word of the last final.
  /// Call when recitation stops.
  @override
  List<QuranMatchEvent> flush() {
    if (!_locked || _carry.isEmpty) {
      _carry = const [];
      return const [];
    }
    return _process('', isFinal: true, hold: false);
  }

  /// Recognized words carried into the next segment: the last word of each
  /// final — recognizers often end a segment in the middle of a word
  /// («الحكي» | «م …») — and, until [_locked], every unlocated word so far.
  List<String> _carry = const [];

  List<QuranMatchEvent> _process(
    String transcript, {
    required bool isFinal,
    bool hold = true,
  }) {
    final keys = [..._carry, ..._n.keysOf(transcript)];
    final events = <QuranMatchEvent>[];
    if (keys.isEmpty) return events;

    final hint = _cursor ?? (_hasFocus ? _focusStart : 0);
    _Alignment alignment;
    if (!_locked) {
      if (keys.length < config.minRelocateWords && !isFinal) {
        _log(transcript, null, pending: true);
        return events;
      }
      final found = _locate(keys, hint, isFinal: isFinal);
      if (found == null) {
        // Keep the words: they may locate together with the next segment.
        if (isFinal) {
          _carry = keys.length > 12 ? keys.sublist(keys.length - 12) : keys;
        }
        _log(transcript, null, pending: true);
        return events;
      }
      alignment = found.$1;
      _locked = true;
      _segmentEmitted = 0;
      final to = alignment.matches.first.position;
      if ((to - hint).abs() > config.maxSkip) {
        events.add(_relocated(to, found.$2));
      }
    } else {
      final expected = _segmentAnchor ?? _cursor!;
      alignment = _align(keys, expected);
      // New evidence that the reciter is somewhere else: look again.
      if (_isPoor(alignment, keys.length) &&
          keys.length >= config.minRelocateWords + 1) {
        final found = _locate(
          keys,
          expected,
          isFinal: isFinal,
          current: alignment,
        );
        if (found != null && found.$1.anchor != expected) {
          alignment = found.$1;
          final to = alignment.matches.first.position;
          events.add(_relocated(to, found.$2));
        }
      }
    }
    // Keep this segment's anchor for its later partials.
    if (keys.length >= config.minRelocateWords || isFinal) {
      _segmentAnchor = alignment.anchor;
    }

    // The last recognized word (with any words merged into it) may still
    // change: in a partial, and at the end of a final, where it is carried
    // into the next segment.
    var stable = keys.length;
    if (!isFinal || hold) {
      stable = keys.length - 1;
      while (stable > 0 &&
          alignment.ops[stable - 1].kind == _OpKind.mergedFirst) {
        stable--;
      }
    }
    var previous = alignment.anchor - 1;
    var emittedEnd = alignment.anchor - 1;
    for (var i = 0; i < alignment.ops.length; i++) {
      final op = alignment.ops[i];
      final isMatch = op.kind == _OpKind.match || op.kind == _OpKind.merged;
      if (i >= _segmentEmitted && i < stable) {
        if (op.kind == _OpKind.extra) {
          _push(0.3);
          events.add(WordHeard(ref: null, heard: keys[i], similarity: 0));
        } else if (isMatch) {
          var first = i;
          while (first > 0 &&
              alignment.ops[first - 1].kind == _OpKind.mergedFirst) {
            first--;
          }
          events.add(
            WordHeard(
              ref: corpus.words[op.position].ref,
              heard: keys.sublist(first, i + 1).join(' '),
              similarity: op.similarity,
            ),
          );
          events.addAll(_eventsFor(op, previous, keys[i]));
        }
      }
      if (isMatch) {
        previous = op.position;
        if (i < stable) emittedEnd = op.position;
      }
    }
    if (stable > _segmentEmitted) _segmentEmitted = stable;

    // The word still being heard, for consumers that react immediately.
    if (stable < alignment.ops.length) {
      final lastOp = alignment.ops.last;
      if (lastOp.kind == _OpKind.match || lastOp.kind == _OpKind.merged) {
        events.add(
          WordHeard(
            ref: corpus.words[lastOp.position].ref,
            heard: keys.sublist(stable).join(' '),
            similarity: lastOp.similarity,
            provisional: true,
          ),
        );
      }
    }

    final last = alignment.lastPosition;
    if (last != null && last != _current) {
      _current = last;
      events.add(CurrentWord(corpus.words[last].ref, confidence: confidence));
    }
    if (isFinal) {
      _segmentAnchor = null;
      _segmentEmitted = 0;
      _carry = keys.sublist(stable);
      // The next segment starts at the first word not yet emitted.
      _cursor = emittedEnd + 1;
    }
    _log(transcript, alignment);
    return events;
  }

  MatchRelocated _relocated(int to, String scope) => MatchRelocated(
    from: _current == null ? null : corpus.words[_current!].ref,
    to: corpus.words[to].ref,
    scope: scope,
  );

  List<QuranMatchEvent> _eventsFor(_Op op, int previous, String heard) {
    final events = <QuranMatchEvent>[];
    final p = op.position;
    // Words passed over since the previous match (not already recited).
    if (p > previous + 1 && p - previous - 1 <= config.maxSkip) {
      for (var s = previous + 1; s < p; s++) {
        if (s > _confirmedMax) {
          events.add(WordSkipped(corpus.words[s].ref));
          _push(0.2);
        }
      }
    }
    final ref = corpus.words[p].ref;
    final good = op.similarity >= config.confirmSimilarity;
    if (p <= _confirmedMax) {
      events.add(WordRepeated(ref));
      if (good && _mistakes.remove(p)) {
        events.add(
          WordConfirmed(ref, similarity: op.similarity, corrected: true),
        );
      }
    } else if (good) {
      events.add(WordConfirmed(ref, similarity: op.similarity));
    } else {
      events.add(PossibleMistake(ref, heard: heard, similarity: op.similarity));
      _mistakes.add(p);
    }
    if (p > _confirmedMax) _confirmedMax = p;
    _push(op.similarity);
    return events;
  }

  void _push(double value) {
    _recent.add(value);
    if (_recent.length > 8) _recent.removeAt(0);
  }

  bool _isPoor(_Alignment a, int words) =>
      words >= config.minRelocateWords && (a.quality < 0.45 || a.good < 2);

  /// Searches progressively wider areas — the visible page and [hint],
  /// then nearby, then the whole Quran — for where [keys] fit. Returns the
  /// best alignment and the area that found it, or `null` when nothing fits
  /// well or the best fit isn't clearly better than the runner-up (wait for
  /// more words then, unless the segment is final). With [current], only
  /// an alignment clearly better than it counts.
  (_Alignment, String)? _locate(
    List<String> keys,
    int hint, {
    required bool isFinal,
    _Alignment? current,
  }) {
    // Candidate start positions, voted by exact skeleton hits.
    final votes = <int, int>{};
    final sample = math.min(keys.length, 12);
    for (var i = 0; i < sample; i++) {
      final hits = corpus.positionsWithSkeleton(_n.skeleton(keys[i]));
      if (hits.length > 600) continue; // too common to locate anything
      for (final p in hits) {
        final start = p - i;
        if (start >= 0) votes[start] = (votes[start] ?? 0) + 1;
      }
    }
    bool nearHint(int s) => (s - hint).abs() <= 20;
    final tiers = <(String, bool Function(int))>[
      (
        'page',
        (s) =>
            nearHint(s) ||
            (_hasFocus && s >= _focusStart - 20 && s <= _focusEnd + 20),
      ),
      ('nearby', (s) => (s - hint).abs() <= 600),
      ('quran', (_) => true),
    ];
    final needed = math.min(3, keys.length);
    for (final (scope, inTier) in tiers) {
      final starts = [
        if (scope == 'page') hint,
        ...(votes.entries.where((e) => e.value >= 2 && inTier(e.key)).toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(8)
            .map((e) => e.key),
      ];
      final alignments = [
        for (final start in starts)
          if (start >= 0 && start < corpus.length) _align(keys, start),
      ]..sort((a, b) => b.score.compareTo(a.score));
      if (alignments.isEmpty) continue;
      final best = alignments.first;
      final bestStart = best.matches.firstOrNull?.position;
      if (bestStart == null ||
          best.good < needed ||
          best.quality < 0.55 ||
          (current != null && best.score < current.score + 0.5)) {
        continue;
      }
      // The strongest alternative somewhere else.
      final rival = alignments.skip(1).where((a) {
        final p = a.matches.firstOrNull?.position;
        return p != null && (p - bestStart).abs() > 3;
      }).firstOrNull;
      if (!isFinal && rival != null && best.score - rival.score < 1.2) {
        return null; // ambiguous: wait for more words
      }
      return (best, scope);
    }
    return null;
  }

  /// Viterbi alignment of [keys] against canonical words, expecting the
  /// first recognized word at [anchor].
  ///
  /// Row r of the search depends only on the first r recognized words, so
  /// when a partial extends the previous one (the usual case) the rows
  /// already computed for the same window are reused.
  _Alignment _align(List<String> keys, int anchor) {
    final m = keys.length;
    final c = config;
    final reach = c.maxBack > c.maxRestart ? c.maxBack : c.maxRestart;
    final lo = math.max(0, anchor - reach - 1);
    // Grown in steps, so consecutive partials share one window.
    final ahead = ((m * 2 + 20 + 63) ~/ 64) * 64;
    final hi = math.min(corpus.length, anchor + ahead);
    // State s ↔ "last matched position" p = lo - 1 + s.
    final states = hi - lo + 1;

    final grid =
        _grid != null &&
            _grid!.anchor == anchor &&
            _grid!.lo == lo &&
            _grid!.hi == hi
        ? _grid!
        : (_grid = _Grid(anchor, lo, hi, states));
    // Rows still valid: those built from the same leading words.
    var valid = 0;
    while (valid < m &&
        valid < grid.keys.length &&
        grid.keys[valid] == keys[valid] &&
        valid + 1 < grid.rows) {
      valid++;
    }
    grid.truncate(valid + 1);
    grid.keys
      ..length = valid
      ..addAll(keys.sublist(valid));
    if (grid.rows == 0) {
      grid.addRow();
      grid.score[0][anchor - 1 - (lo - 1)] = 0;
    }

    double sim(int i, int p) => _cachedSimilarity(keys[i], p);
    double emit(double s) => s >= 0.35 ? 2 * s - 1 : -1.2;
    double transition(int k, int j) {
      if (j == k + 1) return 0;
      if (j > k + 1) return c.skipCost * (j - k - 1);
      if (j == k) return c.repeatCost;
      return c.backCost + 0.15 * (k - j - 1);
    }

    final ayahStarts = grid.ayahStarts ??= [
      for (var p = lo; p < hi; p++)
        if (corpus.words[p].ref.wordIndex == 0) p,
    ];

    for (var i = grid.rows - 1; i < m; i++) {
      grid.addRow();
      final from = grid.score[i];
      final score = grid.score[i + 1];
      final backState = grid.backState[i + 1];
      final backRow = grid.backRow[i + 1];
      final backOp = grid.backOp[i + 1];
      void relax(int s, double value, int fromRow, int fromState, int op) {
        if (value > score[s]) {
          score[s] = value;
          backRow[s] = fromRow;
          backState[s] = fromState;
          backOp[s] = op;
        }
      }

      for (var ks = 0; ks < states; ks++) {
        final base = from[ks];
        if (base == _negInf) continue;
        final k = lo - 1 + ks;
        relax(ks, base - c.extraCost, i, ks, _extra);
        final first = math.max(lo, k - c.maxBack);
        final last = math.min(hi - 1, k + 1 + c.maxSkip);
        for (var j = first; j <= last; j++) {
          final value = base - transition(k, j) + emit(sim(i, j));
          relax(j - (lo - 1), value, i, ks, _match);
        }
        // Going back further, to the start of an ayah.
        for (final j in ayahStarts) {
          if (j >= first || j < k - c.maxRestart) continue;
          final value = base - c.restartCost + emit(sim(i, j));
          relax(j - (lo - 1), value, i, ks, _match);
        }
      }
      // Two to four recognized words for one canonical word: «يا ايها»
      // for «يَٰٓأَيُّهَا», spelled-out letters («الف لام ميم» for «الٓمٓ»),
      // or a word the recognizer split in two.
      for (var len = 2; len <= _maxMerge && len <= i + 1; len++) {
        final fromRow = i + 1 - len;
        final joined = keys.sublist(fromRow, i + 1).join();
        final fromScore = grid.score[fromRow];
        for (var ks = 0; ks < states; ks++) {
          final base = fromScore[ks];
          if (base == _negInf) continue;
          final k = lo - 1 + ks;
          final last = math.min(hi - 1, k + 1 + c.maxSkip);
          for (var j = math.max(lo, k + 1); j <= last; j++) {
            if (!_lengthsClose(joined, j)) continue;
            final s = _cachedSimilarity(joined, j);
            if (s < 0.85) continue;
            // Slightly better than matching the pieces separately.
            final value = base - transition(k, j) + emit(s) + 0.3 * (len - 1);
            relax(j - (lo - 1), value, fromRow, ks, _merged);
          }
        }
      }
    }

    final finalRow = grid.score[m];
    var bestState = 0;
    for (var s = 1; s < states; s++) {
      if (finalRow[s] > finalRow[bestState]) bestState = s;
    }
    final ops = List<_Op>.filled(m, const _Op(_OpKind.extra));
    var row = m, s = bestState;
    while (row > 0) {
      final op = grid.backOp[row][s];
      final p = lo - 1 + s;
      final prevRow = grid.backRow[row][s];
      if (op == _merged) {
        final value = _cachedSimilarity(keys.sublist(prevRow, row).join(), p);
        ops[row - 1] = _Op(_OpKind.merged, p, value);
        for (var r = prevRow; r < row - 1; r++) {
          ops[r] = _Op(_OpKind.mergedFirst, p, value);
        }
      } else if (op == _match) {
        ops[row - 1] = _Op(_OpKind.match, p, sim(row - 1, p));
      }
      s = grid.backState[row][s];
      row = prevRow;
    }
    return _Alignment(ops, finalRow[bestState], anchor);
  }

  static const _negInf = -1e18;
  static const _extra = 0, _match = 1, _merged = 2;

  /// The last search grid, reused by the next partial when possible.
  _Grid? _grid;

  /// Similarities already computed, by (recognized key, position) — the
  /// same words come back in every partial of a segment.
  final _similarities = <int, double>{};
  final _keyIds = <String, int>{};

  double _cachedSimilarity(String key, int position) {
    if (_similarities.length > 400000) {
      _similarities.clear();
      _keyIds.clear();
    }
    final id = _keyIds.putIfAbsent(key, () => _keyIds.length);
    return _similarities.putIfAbsent(
      id * corpus.length + position,
      () => _similarity(key, position),
    );
  }

  /// Whether [joined] is close enough in length to the word at [position]
  /// (or its spoken letters) to be worth comparing for a merge.
  bool _lengthsClose(String joined, int position) {
    final word = corpus.words[position];
    if ((joined.length - word.key.length).abs() <= 2) return true;
    final spoken = word.spoken;
    return spoken != null && (joined.length - spoken.length).abs() <= 2;
  }

  static const _maxMerge = 4;

  /// Similarity of recognized [key] to the canonical word at [position],
  /// also against the spoken letter names of the muqaṭṭaʿāt.
  double _similarity(String key, int position) {
    final word = corpus.words[position];
    final written = quranWordSimilarity(key, word.key, n: _n);
    final spoken = word.spoken;
    if (spoken == null || written == 1) return written;
    return math.max(written, quranWordSimilarity(key, spoken, n: _n));
  }

  void _log(String transcript, _Alignment? a, {bool pending = false}) {
    final sink = log;
    if (sink == null) return;
    final parts = <String>[];
    for (final op in a?.ops ?? const <_Op>[]) {
      switch (op.kind) {
        case _OpKind.extra:
          parts.add('+extra');
        case _OpKind.mergedFirst:
          break;
        case _OpKind.match || _OpKind.merged:
          final w = corpus.words[op.position];
          final mark = op.similarity >= config.confirmSimilarity ? '✓' : '?';
          parts.add(
            '${w.text} ${_fmt(w.ref)}$mark${op.similarity.toStringAsFixed(2)}',
          );
      }
    }
    final cur = _current == null ? '-' : _fmt(corpus.words[_current!].ref);
    sink(
      'ASR "$transcript" → [${parts.join(', ')}] → '
      '${pending ? 'locating…' : 'current $cur'} '
      '(confidence ${confidence.toStringAsFixed(2)})',
    );
  }
}

/// One Viterbi search grid over a window of canonical positions: a row per
/// recognized word, a column per "last matched position".
class _Grid {
  _Grid(this.anchor, this.lo, this.hi, this.states);

  final int anchor, lo, hi, states;
  final keys = <String>[];
  final score = <Float64List>[];
  final backState = <Int32List>[];
  final backRow = <Int32List>[];
  final backOp = <Uint8List>[];
  List<int>? ayahStarts;

  int get rows => score.length;

  void addRow() {
    score.add(Float64List(states)..fillRange(0, states, -1e18));
    backState.add(Int32List(states));
    backRow.add(Int32List(states));
    backOp.add(Uint8List(states));
  }

  void truncate(int count) {
    if (count >= rows) return;
    score.length = count;
    backState.length = count;
    backRow.length = count;
    backOp.length = count;
  }
}
