import 'dart:math' as math;
import 'dart:typed_data';

import 'quran_acoustic_model.dart';
import 'quran_phonetic_reference.dart';

const _neg = -1e30;

double _logAdd(double a, double b) {
  if (a < b) return _logAdd(b, a);
  if (b <= _neg) return a;
  return a + math.log(1 + math.exp(b - a));
}

/// Sounds whose length varies — the long vowels (madd: ا ۦ ۥ) and the
/// nasal (ghunnah: ں). The model spells a long one as the symbol repeated
/// with blanks between (a six-count madd: ا _ ا _ ا …), while the expected
/// pronunciation has it once (its length is not judged): one such token may
/// take the symbol again after a blank.
final Set<int> stretchableTokens = {
  for (final c in const ['ا', 'ۦ', 'ۥ', 'ں']) phoneticClassOf(c),
};

/// Frames a token was aligned to (inclusive).
typedef FrameSpan = ({int start, int end});

/// The result of a forced alignment.
class CtcAlignment {
  const CtcAlignment(this.spans, this.score);

  /// Per expected token, its frames; `null` for a skipped optional token.
  final List<FrameSpan?> spans;

  /// Log-probability of the best path.
  final double score;
}

/// CTC forced alignment: the single most likely way the frames spell out
/// a *known* token sequence (Viterbi over the CTC graph — blank, token,
/// blank, …). Tokens marked optional may be skipped.
///
/// With [startAt] / [endAt] (token indices), the frames may spell out only
/// part of the sequence: starting at any token in [startAt] and ending
/// after any token in [endAt] — for locating an utterance among candidate
/// words. Tokens outside that part get no span.
CtcAlignment ctcForcedAlign(
  AcousticFrames frames,
  List<int> tokens, {
  List<bool>? optional,
  Set<int>? startAt,
  Set<int>? endAt,
}) {
  final n = tokens.length;
  final labels = <int>[];
  for (final t in tokens) {
    labels
      ..add(ctcBlank)
      ..add(t);
  }
  labels.add(ctcBlank);
  final s = labels.length;
  final opt = optional ?? List<bool>.filled(n, false);

  final preds = List.generate(s, (i) => <int>[i]);
  for (var i = 1; i < s; i++) {
    preds[i].add(i - 1);
    if (i >= 2 && labels[i] != ctcBlank && labels[i] != labels[i - 2]) {
      preds[i].add(i - 2);
    }
  }
  // A stretchable token, after the blank that follows it, again.
  for (var i = 1; i + 1 < s; i += 2) {
    if (stretchableTokens.contains(labels[i])) preds[i].add(i + 1);
  }
  for (var k = 0; k < n; k++) {
    if (!opt[k]) continue;
    final i = 2 * k + 1;
    preds[i + 1].add(i - 1);
    if (i - 2 >= 0) preds[i + 1].add(i - 2);
    if (i + 2 < s) {
      preds[i + 2].add(i - 1);
      if (i - 2 >= 0 && labels[i + 2] != labels[i - 2]) preds[i + 2].add(i - 2);
    }
  }

  final t = frames.frames;
  var dp = Float64List(s)..fillRange(0, s, _neg);
  dp[0] = frames.at(0, labels[0]);
  if (s > 1) dp[1] = frames.at(0, labels[1]);
  if (n > 0 && opt[0] && s > 3) {
    dp[2] = frames.at(0, ctcBlank);
    dp[3] = frames.at(0, labels[3]);
  }
  for (final k in startAt ?? const <int>{}) {
    dp[2 * k] = frames.at(0, ctcBlank);
    dp[2 * k + 1] = frames.at(0, labels[2 * k + 1]);
  }
  final back = Int32List(t * s);
  for (var f = 1; f < t; f++) {
    final next = Float64List(s);
    for (var i = 0; i < s; i++) {
      var best = _neg;
      var arg = i;
      for (final p in preds[i]) {
        if (dp[p] > best) {
          best = dp[p];
          arg = p;
        }
      }
      next[i] = best + frames.at(f, labels[i]);
      back[f * s + i] = arg;
    }
    dp = next;
  }
  var end = s - 1;
  if (s >= 2 && dp[s - 2] > dp[s - 1]) end = s - 2;
  for (final k in endAt ?? const <int>{}) {
    for (final i in [2 * k + 1, 2 * k + 2]) {
      if (dp[i] > dp[end]) end = i;
    }
  }
  if (n > 0 && opt[n - 1] && s >= 3 && dp[s - 3] > dp[end]) end = s - 3;
  final score = dp[end];
  final spans = List<FrameSpan?>.filled(n, null);
  var state = end;
  for (var f = t - 1; f >= 0; f--) {
    if (state.isOdd) {
      final k = state ~/ 2;
      final span = spans[k];
      spans[k] = span == null ? (start: f, end: f) : (start: f, end: span.end);
    }
    if (f > 0) state = back[f * s + state];
  }
  return CtcAlignment(spans, score);
}

/// log P(tokens | frames) over all CTC paths (the forward algorithm).
double ctcLogProbability(AcousticFrames frames, List<int> tokens) {
  final ext = <int>[ctcBlank];
  for (final t in tokens) {
    ext
      ..add(t)
      ..add(ctcBlank);
  }
  final s = ext.length;
  if (frames.frames == 0) return _neg;
  var a = Float64List(s)..fillRange(0, s, _neg);
  a[0] = frames.at(0, ctcBlank);
  if (s > 1) a[1] = frames.at(0, ext[1]);
  for (var f = 1; f < frames.frames; f++) {
    final next = Float64List(s);
    for (var i = 0; i < s; i++) {
      var v = a[i];
      if (i >= 1) v = _logAdd(v, a[i - 1]);
      if (i >= 2 && ext[i] != ctcBlank && ext[i] != ext[i - 2]) {
        v = _logAdd(v, a[i - 2]);
      }
      if (i.isOdd && i + 1 < s && stretchableTokens.contains(ext[i])) {
        v = _logAdd(v, a[i + 1]);
      }
      next[i] = v + frames.at(f, ext[i]);
    }
    a = next;
  }
  return s > 1 ? _logAdd(a[s - 1], a[s - 2]) : a[s - 1];
}
