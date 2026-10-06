import 'dart:math' as math;
import 'dart:typed_data';

import '../acoustic/quran_acoustic_model.dart';
import '../acoustic/quran_phonetic_reference.dart';

/// A place in the Quran where a decoded phoneme sequence may be.
class PhonemeCandidate {
  const PhonemeCandidate({
    required this.firstWord,
    required this.lastWord,
    required this.votes,
  });

  /// Corpus positions the sequence would cover (roughly).
  final int firstWord, lastWord;

  /// Shared phoneme n-grams in agreeing order.
  final int votes;

  @override
  String toString() => 'PhonemeCandidate($firstWord..$lastWord, $votes)';
}

/// The whole Quran's expected pronunciation, indexed for finding where a
/// stretch of recitation is: the first stage of locating the reciter from
/// acoustic frames (no text, no network). Candidates found here are then
/// scored against the frames themselves (CTC).
///
/// Sequences are compared in a reduced form — optional markers dropped,
/// repeated symbols merged (a long vowel or a doubled consonant is one
/// symbol) — since a greedy decode of the frames does not reliably keep
/// lengths. Lookup is by shared [n]-grams voting for where the sequence
/// starts; ~450k symbols take ~3.6 MB.
class QuranPhonemeIndex {
  QuranPhonemeIndex._(this.tokens, this.words, this._keys, this._byKey);

  static const n = 5;
  static final _base = quranPhoneticVocabulary.length;

  /// Builds from [reference], with each ayah's first corpus position.
  /// Runs in a background isolate in the app (~1 s).
  factory QuranPhonemeIndex.build(
    QuranPhoneticReference reference,
    List<(int ayahId, int firstPosition)> ayahs,
  ) {
    final tokens = <int>[], words = <int>[];
    for (final (ayahId, first) in ayahs) {
      final e = reference.encoded(ayahId);
      if (e == null) continue;
      for (var i = 0; i < e.classes.length; i++) {
        if (tokens.isNotEmpty && tokens.last == e.classes[i]) continue;
        tokens.add(e.classes[i]);
        words.add(first + e.words[i]);
      }
    }
    final count = math.max(0, tokens.length - n + 1);
    final keys = Int32List(count);
    for (var i = 0; i < count; i++) {
      keys[i] = _key(tokens, i);
    }
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) => keys[a].compareTo(keys[b]));
    return QuranPhonemeIndex._(
      Uint8List.fromList(tokens),
      Int32List.fromList(words),
      Int32List.fromList([for (final i in order) keys[i]]),
      Int32List.fromList(order),
    );
  }

  /// The reduced sequence, and each symbol's corpus position.
  final Uint8List tokens;
  final Int32List words;

  /// N-gram keys in sorted order, and the token index of each.
  final Int32List _keys, _byKey;

  static int _key(List<int> t, int at) {
    var k = 0;
    for (var j = 0; j < n; j++) {
      k = k * _base + t[at + j];
    }
    return k;
  }

  /// The reduced form of a symbol sequence.
  static List<int> reduce(Iterable<int> symbols) {
    final out = <int>[];
    for (final s in symbols) {
      if (s == ctcBlank || _markers.contains(s)) continue;
      if (out.isNotEmpty && out.last == s) continue;
      out.add(s);
    }
    return out;
  }

  /// Symbols the reference only uses as optional markers.
  static final _markers = {
    for (final s in const ['ڇ', 'ۜ']) phoneticClassOf(s),
  };

  /// Greedy decode of [frames]: the most likely symbol per frame, reduced.
  static List<int> decode(AcousticFrames frames) {
    final best = <int>[];
    var previous = -1;
    for (var f = 0; f < frames.frames; f++) {
      var arg = 0;
      var top = double.negativeInfinity;
      for (var c = 0; c < frames.classes; c++) {
        final v = frames.at(f, c);
        if (v > top) {
          top = v;
          arg = c;
        }
      }
      if (arg != previous) best.add(arg);
      previous = arg;
    }
    return reduce(best);
  }

  int _lower(int key) {
    var lo = 0, hi = _keys.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_keys[mid] < key) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Where [hypothesis] (reduced) may be: up to [limit] places, best
  /// first, optionally only among corpus positions [from]..[to]. N-grams
  /// found more than [maxHits] times (common syllables) are not used.
  List<PhonemeCandidate> lookup(
    List<int> hypothesis, {
    int? from,
    int? to,
    int limit = 8,
    int maxHits = 3000,
  }) {
    const bin = 4;
    final votes = <int, int>{};
    for (var i = 0; i + n <= hypothesis.length; i++) {
      final key = _key(hypothesis, i);
      final lo = _lower(key);
      var hi = lo;
      while (hi < _keys.length && _keys[hi] == key) {
        hi++;
      }
      if (hi - lo > maxHits) continue;
      final seen = <int>{};
      for (var j = lo; j < hi; j++) {
        final p = _byKey[j];
        final w = words[p];
        if ((from != null && w < from) || (to != null && w > to)) continue;
        // Where the hypothesis would start, binned (insertions and
        // deletions shift it a little); one vote per n-gram per bin.
        final start = (p - i) ~/ bin;
        if (seen.add(start)) votes[start] = (votes[start] ?? 0) + 1;
      }
    }
    final ranked = votes.entries.toList()
      ..sort((a, b) {
        final byVotes = b.value.compareTo(a.value);
        return byVotes != 0 ? byVotes : a.key.compareTo(b.key);
      });
    final out = <PhonemeCandidate>[];
    final taken = <int>[];
    final span = hypothesis.length ~/ bin + 1;
    for (final MapEntry(key: start, value: v) in ranked) {
      if (v < 2) break;
      // Neighbouring bins of the same place count as one candidate.
      if (taken.any((t) => (t - start).abs() <= span)) continue;
      taken.add(start);
      final first = (start * bin).clamp(0, tokens.length - 1);
      final last = (start * bin + hypothesis.length).clamp(
        0,
        tokens.length - 1,
      );
      out.add(
        PhonemeCandidate(
          firstWord: words[first],
          lastWord: words[last],
          votes: v,
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }
}
