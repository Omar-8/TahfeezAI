import '../../quran/domain/models/quran_refs.dart';
import '../matching/quran_match_normalizer.dart';
import '../matching/quran_stream_matcher.dart';
import '../matching/quran_word_corpus.dart';

/// How one recited word was judged against the memorization range.
enum HifzVerdict {
  /// The expected word, recited as written.
  correct,

  /// The expected word was passed over.
  skipped,

  /// Something else was recited in the expected word's place.
  wrong,

  /// A word matching nothing (hesitation filler, stray word).
  extra,

  /// An already-revealed word recited again.
  repeated,

  /// The expected word recited correctly after a mistake on it.
  selfCorrected,

  /// The expected word with only similar-sounding letters different
  /// («صنه» for «سنه») — a recognition confusion or a pronunciation
  /// (makhraj) matter, which this mode does not judge. Revealed, flagged,
  /// not held against the reciter.
  uncertain,
}

class HifzEvent {
  const HifzEvent(this.verdict, {this.ref, this.heard, this.similarity = 0});
  final HifzVerdict verdict;

  /// The canonical word judged (`null` for [HifzVerdict.extra]).
  final WordRef? ref;
  final String? heard;
  final double similarity;

  @override
  String toString() =>
      '${verdict.name.toUpperCase()}'
      '${ref == null ? '' : ' ${ref!.ayahId ~/ 1000}:${ref!.ayahId % 1000}:${ref!.wordIndex + 1}'}'
      '${heard == null ? '' : ' "$heard"'}';
}

class HifzConfig {
  const HifzConfig({this.strict = true, this.confirmSimilarity = 0.72});

  /// Strict: a wrong or skipped word holds the expected word — nothing
  /// further is revealed until it is corrected. Lenient: the mistake is
  /// marked, the word revealed, and the test moves on.
  final bool strict;

  /// Similarity from which the expected word counts as recited correctly.
  final double confirmSimilarity;
}

/// Letters recognizers (and learners' pronunciation) commonly confuse,
/// folded together. Two words equal under this fold differ only in sound,
/// not in which word was recited.
const _soundAlike = {
  'ط': 'ت',
  'ص': 'س',
  'ث': 'س',
  'ض': 'د',
  'ظ': 'ذ',
  'ز': 'ذ',
  'ق': 'ك',
  'ح': 'ه',
  'ع': 'ا',
  'غ': 'خ',
};

String _soundKey(String key) => const QuranMatchNormalizer().skeleton(
  key.split('').map((c) => _soundAlike[c] ?? c).join(),
);

/// Judges a live recitation against a memorization range, word by word.
///
/// Consumes the matcher's [WordHeard] stream (where each recognized word
/// landed, and how well it matched) and keeps its own strict notion of the
/// *expected* word: only the expected word, recited correctly, advances
/// the test and is revealed.
class HifzJudge {
  HifzJudge(
    this.corpus, {
    required this.start,
    required this.end,
    this.config = const HifzConfig(),
  }) : expected = start;

  final QuranWordCorpus corpus;

  /// First and last corpus positions of the memorization range. [start]
  /// moves back if the reciter jumps to an earlier place ([jumpTo]).
  int start;
  final int end;
  final HifzConfig config;

  /// The next word the reciter should say.
  int expected;

  /// Range positions already revealed.
  final Set<int> revealed = {};

  /// Revealed before the test began ([preReveal]) — not recited in it.
  final Set<int> given = {};

  /// Range positions revealed with a mistake on them (lenient mode, or an
  /// uncertain match) — kept for feedback.
  final Map<int, HifzVerdict> marked = {};

  /// A mistake on [expected] waiting for correction, if any.
  HifzVerdict? pending;

  /// While the reciter goes back over words already revealed (re-reciting
  /// an earlier ayah): the next word of that review — where they are now.
  /// `null` when they are at [expected].
  int? reviewing;

  /// Where the reciter is: [reviewing] while going back over revealed
  /// words, otherwise [expected].
  int get current => reviewing ?? expected;

  /// Following the reciter back over revealed words (word [p] just said).
  void _review(int p) {
    reviewing = p + 1 < expected ? p + 1 : null;
  }

  /// Counts per verdict, for the session summary.
  final Map<HifzVerdict, int> counts = {
    for (final v in HifzVerdict.values) v: 0,
  };

  bool get completed => expected > end;

  WordRef? get expectedRef => completed ? null : corpus.words[expected].ref;

  /// A word matched nothing since the last matched word; it probably stood
  /// in for the expected one.
  String? _unplaced;

  /// Positions already judged from a provisional report (the word still
  /// being heard), so their stable report isn't judged again.
  final Set<int> _early = {};

  /// Marks the range's first [count] words as already revealed (e.g.
  /// uncovered by hand before reciting): the test starts after them.
  void preReveal(int count) {
    for (var p = start; p < start + count && p <= end; p++) {
      revealed.add(p);
      given.add(p);
    }
    while (expected <= end && revealed.contains(expected)) {
      expected++;
    }
  }

  /// Moves the test to [position] — the reciter went somewhere else (e.g.
  /// turned the page). Nothing between is judged; revealed words stay.
  void jumpTo(int position) {
    if (position < start) start = position;
    expected = position.clamp(start, end + 1);
    pending = null;
    reviewing = null;
    _unplaced = null;
    _early.clear();
    while (expected <= end && revealed.contains(expected)) {
      expected++;
    }
  }

  /// Reveals the expected word — or the rest of its ayah — without it
  /// being recited: those words count as [HifzVerdict.skipped].
  List<HifzEvent> revealManually({bool wholeAyah = false}) {
    if (completed) return const [];
    var until = expected;
    if (wholeAyah) {
      final verse = corpus.words[expected].verse;
      while (until + 1 <= end && corpus.words[until + 1].verse == verse) {
        until++;
      }
    }
    final events = <HifzEvent>[];
    for (var q = expected; q <= until; q++) {
      if (revealed.contains(q)) continue;
      events.add(
        _count(HifzEvent(HifzVerdict.skipped, ref: corpus.words[q].ref)),
      );
      _reveal(q, mark: HifzVerdict.skipped);
    }
    expected = until;
    _advance();
    return events;
  }

  /// Hides the last revealed word again — or back to the start of its
  /// ayah (the whole previous ayah, when the expected word starts one) —
  /// and expects it next. `false` at the start of the range.
  bool hideBack({bool wholeAyah = false}) {
    if (expected <= start) return false;
    var target = expected - 1;
    if (wholeAyah) {
      final verse = corpus.words[target].verse;
      while (target - 1 >= start && corpus.words[target - 1].verse == verse) {
        target--;
      }
    }
    for (var q = target; q < expected; q++) {
      revealed.remove(q);
      marked.remove(q);
      _early.remove(q);
    }
    expected = target;
    pending = null;
    reviewing = null;
    _unplaced = null;
    return true;
  }

  List<HifzEvent> onHeard(WordHeard heard) {
    if (completed) return const [];
    final ref = heard.ref;
    if (heard.provisional) return _onProvisional(heard);
    if (ref == null) {
      _unplaced = heard.heard;
      return [_count(HifzEvent(HifzVerdict.extra, heard: heard.heard))];
    }
    final p = corpus.positionOf(ref);
    if (p != null && _early.contains(p)) {
      // Already judged while it was still being heard.
      _early.removeWhere((q) => q <= p);
      return const [];
    }
    final unplaced = _unplaced;
    _unplaced = null;
    if (p == null || p > end) return const [];
    if (p < expected) {
      if (p >= start) _review(p);
      return p < start
          ? const []
          : [
              _count(
                HifzEvent(HifzVerdict.repeated, ref: ref, heard: heard.heard),
              ),
            ];
    }

    final events = <HifzEvent>[];
    if (p > expected) {
      // A word the matcher couldn't place, standing exactly where the
      // expected word was: a wrong word, not a skip.
      final substituted = unplaced != null && p == expected + 1;
      if (config.strict) {
        final kind = substituted ? HifzVerdict.wrong : HifzVerdict.skipped;
        if (pending == null) {
          pending = kind;
          events.add(
            _count(
              HifzEvent(
                kind,
                ref: corpus.words[expected].ref,
                heard: substituted ? unplaced : null,
              ),
            ),
          );
        }
        return events; // held until the expected word is recited
      }
      for (var q = expected; q < p; q++) {
        final kind = substituted ? HifzVerdict.wrong : HifzVerdict.skipped;
        events.add(
          _count(
            HifzEvent(
              kind,
              ref: corpus.words[q].ref,
              heard: substituted ? unplaced : null,
            ),
          ),
        );
        _reveal(q, mark: kind);
      }
      expected = p;
    }

    // p == expected
    final s = heard.similarity;
    if (s >= config.confirmSimilarity) {
      final verdict = pending == null
          ? HifzVerdict.correct
          : HifzVerdict.selfCorrected;
      events.add(
        _count(HifzEvent(verdict, ref: ref, heard: heard.heard, similarity: s)),
      );
      _reveal(p, mark: verdict == HifzVerdict.selfCorrected ? verdict : null);
      _advance();
    } else if (_soundKey(heard.heard.replaceAll(' ', '')) ==
        _soundKey(corpus.words[p].key)) {
      events.add(
        _count(
          HifzEvent(
            HifzVerdict.uncertain,
            ref: ref,
            heard: heard.heard,
            similarity: s,
          ),
        ),
      );
      _reveal(p, mark: HifzVerdict.uncertain);
      _advance();
    } else {
      events.add(
        _count(
          HifzEvent(
            HifzVerdict.wrong,
            ref: ref,
            heard: heard.heard,
            similarity: s,
          ),
        ),
      );
      if (config.strict) {
        pending = HifzVerdict.wrong;
      } else {
        _reveal(p, mark: HifzVerdict.wrong);
        _advance();
      }
    }
    return events;
  }

  /// The word still being heard counts right away only when it is clearly
  /// the expected word; anything less waits for its stable report.
  List<HifzEvent> _onProvisional(WordHeard heard) {
    final ref = heard.ref;
    final p = ref == null ? null : corpus.positionOf(ref);
    // Going back over revealed words: follow them at once, word by word.
    if (p != null && p < expected && p >= start) {
      _review(p);
      return const [];
    }
    if (p == null ||
        p != expected ||
        heard.similarity < config.confirmSimilarity) {
      return const [];
    }
    final verdict = pending == null
        ? HifzVerdict.correct
        : HifzVerdict.selfCorrected;
    _early.add(p);
    _unplaced = null;
    final event = _count(
      HifzEvent(
        verdict,
        ref: ref,
        heard: heard.heard,
        similarity: heard.similarity,
      ),
    );
    _reveal(p, mark: verdict == HifzVerdict.selfCorrected ? verdict : null);
    _advance();
    return [event];
  }

  HifzEvent _count(HifzEvent event) {
    counts[event.verdict] = counts[event.verdict]! + 1;
    return event;
  }

  void _reveal(int position, {HifzVerdict? mark}) {
    revealed.add(position);
    if (mark != null) marked[position] = mark;
  }

  void _advance() {
    pending = null;
    reviewing = null;
    expected++;
    while (expected <= end && revealed.contains(expected)) {
      expected++;
    }
  }
}
