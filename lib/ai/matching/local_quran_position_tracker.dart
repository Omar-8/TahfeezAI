import 'dart:math' as math;
import 'dart:typed_data';

import '../../quran/domain/models/quran_refs.dart';
import '../acoustic/acoustic_frame_stream.dart';
import '../acoustic/ctc.dart';
import '../acoustic/quran_acoustic_model.dart';
import '../acoustic/quran_phonetic_reference.dart';
import 'quran_phoneme_index.dart';
import 'quran_stream_matcher.dart';
import 'quran_word_corpus.dart';
import 'recitation_position_matcher.dart';

/// A placed word and the stream frames it was heard in (inclusive).
typedef WordPlacement = ({WordRef ref, int start, int end});

/// What the tracker needs that loads in the background.
typedef PhonemeResources = ({
  QuranPhoneticReference reference,
  QuranPhonemeIndex index,
});

/// Tunables for [LocalQuranPositionTracker]. Costs are in nats per frame:
/// how much less likely the frames are under the expected pronunciation
/// than under the model's own best reading of them (0 = a perfect fit).
/// Calibrated on real recitation (`test/fixtures/acoustic/position`):
/// correct continuations cost 0.1–0.5, other passages 0.9 and up.
class LocalPositionTrackerConfig {
  const LocalPositionTrackerConfig({
    this.followCost = 0.8,
    this.pauseFollowCost = 1.6,
    this.pageCost = 0.8,
    this.nearbyCost = 0.7,
    this.quranCost = 0.5,
    this.margin = 0.15,
    this.minLocateSymbols = 14,
    this.minLocateFrames = 20,
    this.lookBack = 8,
    this.lookAhead = 12,
    this.maxPendingFrames = 250,
    this.relocateAfterFrames = 60,
    this.wrongWordCost = 2.5,
    this.repeatCost = 0.8,
    this.minRepeatSounds = 4,
    this.extraFrames = 8,
    this.pauseFrames = 5,
    this.endMargin = 3,
  });

  /// The most the next word may cost when the audio paused
  /// right after them: the pause settles where they end, and a tajweed
  /// sound the model is unsure of (a long ghunna, a stretched madd before
  /// a stop) otherwise holds an ayah's last word until the next is said.
  final double pauseFollowCost;

  /// The most a continuation (or a nearby skip / repeat) may cost.
  final double followCost;

  /// The most a located place may cost: on the visible page, nearby, or
  /// anywhere in the Quran (the further, the surer it must be).
  final double pageCost, nearbyCost, quranCost;

  /// How much better than any other place the located one must fit, unless
  /// it is in a nearer search area (the visible page, then nearby).
  final double margin;

  /// Audio needed before locating: decoded symbols, and frames on the
  /// sounds of the words that fit (0.8 s).
  final int minLocateSymbols, minLocateFrames;

  /// Words around the expected one a continuation may go back / ahead to.
  final int lookBack, lookAhead;

  /// The most unexplained audio kept (10 s): older audio is given up on.
  final int maxPendingFrames;

  /// Speech that won't fit around the expected word, before searching
  /// further afield (2.4 s).
  final int relocateAfterFrames;

  /// A word fitting worse than this was something else said in its place.
  final double wrongWordCost;

  /// Going back (or skipping ahead) is believed only if the words said fit
  /// this well and hold this many sounds — a held vowel or a fragment can otherwise
  /// pass for a short word just said.
  final double repeatCost;
  final int minRepeatSounds;

  /// Unplaced speech this long (0.32 s) is reported (an extra word).
  final int extraFrames;

  /// Silence that separates what fits from speech after it (0.2 s).
  final int pauseFrames;

  /// Frames after a word's last sound before it counts as finished.
  final int endMargin;
}

/// Follows the reciter through the Quran from the on-device acoustic
/// model's frames alone — no recognizer, no text, no network.
///
/// **Following** (once located): the frames since the last word placed are
/// force-aligned (CTC) to the expected next words; finished words are
/// reported. If they don't fit, the alignment may start a few words back
/// (a repeat, going back) or ahead (a skip). Speech before what fits is
/// explained if it can be — a false start placed as words (so a correction
/// reads as one), the isti'adha or a surah's opening basmala passed over —
/// or else reported as something said that is not the text.
///
/// **Locating** (at the start, or when the reciter can't be followed):
/// two stages, never a brute-force search. The frames are decoded greedily
/// into phoneme symbols, looked up in [QuranPhonemeIndex] — the visible
/// page first, then nearby, then the whole Quran — and only the few
/// candidates found are scored against the frames. A place is taken only
/// when it fits clearly better than every other; identical passages
/// (repeated phrases) stay unresolved until more audio, or the visible
/// page, tells them apart. Uncertain beats confidently wrong.
///
/// Emits the same events as [QuranStreamMatcher], so Hifz is unchanged.
class LocalQuranPositionTracker implements RecitationPositionMatcher {
  LocalQuranPositionTracker(
    this.corpus,
    this._resources, {
    this.config = const LocalPositionTrackerConfig(),
    this.log,
  }) : _formulas = [
         for (final (ayah, first, last) in const [
           (1001, 0, 3), // بسم الله الرحمن الرحيم — before any surah
           (16098, 4, 7), // (أعوذ) بالله من الشيطان الرجيم — the isti'adha
         ])
           if (corpus.positionOf((ayahId: ayah, wordIndex: first))
               case final from?)
             (from, from + last - first),
       ];

  final QuranWordCorpus corpus;
  final PhonemeResources? Function() _resources;
  final LocalPositionTrackerConfig config;
  final void Function(String line)? log;

  /// Formulas said around recitation that are also Quran text elsewhere:
  /// passed over unless that text is where the reciter is.
  final List<(int, int)> _formulas;

  final _frames = _FrameBuffer();

  int? _cursor;
  bool _locked = false;
  int _focusStart = 0, _focusEnd = 0;
  bool _hasFocus = false;

  /// The first frame not yet explained.
  int _mark = 0;
  int _emittedMax = -1;
  int? _current;

  /// Words placed so far (going back to one of these is a repeat; going
  /// back to a word passed over is a correction).
  final _placedWords = <int>{};

  /// Stream frame just after the last placed word (for latency).
  int? lastPlacedFrame;

  /// Words placed since the consumer last took them, with their frames —
  /// so the verifier checks exactly the audio each word was heard in.
  final placements = <WordPlacement>[];

  /// The last placed word's closing sounds: a held vowel or consonant
  /// (madd at a pause) runs on past where the alignment ended it, and is
  /// still that word, not the start of the next.
  Set<int> _tail = const {};

  /// The reciter has been located.
  bool get locked => _locked;
  WordRef? get current => _current == null ? null : corpus.words[_current!].ref;

  /// Follows the reciter from [anchor] (trusted: no locating first). The
  /// frames already heard are passed over — or, with [from], those from that
  /// stream frame on are followed too (a loop starting its range again while
  /// the reciter is already a word or two into it).
  @override
  void start({int? anchor, bool trustAnchor = false, int? from}) {
    _cursor = anchor;
    _locked = trustAnchor && anchor != null;
    _mark = from == null
        ? _frames.end
        : from.clamp(_frames.start, _frames.end).toInt();
    _emittedMax = -1;
    _current = null;
    _placedWords.clear();
    _tail = const {};
    lastPlacedFrame = null;
  }

  @override
  void setFocus(int start, int end) {
    _focusStart = start;
    _focusEnd = end;
    _hasFocus = true;
  }

  /// New frames of the stream (contiguous, as [AcousticFrameStore] gives
  /// them).
  List<QuranMatchEvent> onFrames(TimedAcousticFrames chunk) {
    _frames.add(chunk);
    if (_mark < _frames.start) _mark = _frames.start;
    return _process(flush: false);
  }

  @override
  List<QuranMatchEvent> flush() => _process(flush: true);

  List<QuranMatchEvent> _process({required bool flush}) {
    final resources = _resources();
    final events = <QuranMatchEvent>[];
    // Each step explains audio from the start; repeat while it does.
    for (var step = 0; step < 6; step++) {
      final end = _frames.end;
      _absorbTail(end, resources);
      // Silence before the next sound is never anyone's word.
      while (_mark < end && _frames.isBlank(_mark)) {
        _mark++;
      }
      if (resources == null) {
        // Not loaded yet: keep only the recent audio.
        _mark = math.max(_mark, end - config.maxPendingFrames);
        break;
      }
      final from = math.max(_frames.start, _mark - 2);
      final speech = _frames.speechFrames(from, end);
      // At a pause, a word whose long sounds the model hears mostly as
      // blanks (a ghunna, a madd) may show only a couple of frames.
      if (speech < (flush ? 2 : 4)) break;
      final window = _frames.view(from, end);
      final before = _mark;
      if (_locked) {
        final follow = _follow(resources, window, from, flush);
        if (follow != null) {
          events.addAll(follow);
        } else if (speech >= config.relocateAfterFrames ||
            (flush && speech >= config.minLocateFrames)) {
          events.addAll(_locate(resources, window, from, flush));
        }
      } else {
        events.addAll(_locate(resources, window, from, flush));
      }
      if (_mark == before) break;
    }
    if (_frames.end - _mark > config.maxPendingFrames) {
      // Unplaceable for too long: give up on the oldest audio.
      _log('dropping ${_frames.end - _mark - config.maxPendingFrames} frames');
      _mark = _frames.end - config.maxPendingFrames;
    }
    _frames.dropBefore(_mark - 2);
    return events;
  }

  /// Moves past the last placed word's held closing sounds (with short
  /// gaps), up to the first real pause or a different sound — unless the
  /// next word begins with one of them: «إِلَّا ٱلَّذِينَ» said joined ends
  /// and begins with «لَّ», and absorbing it left «ٱلَّذِينَ» without its start.
  void _absorbTail(int end, PhonemeResources? resources) {
    if (_tail.isEmpty) return;
    final next = _cursor;
    if (resources != null && next != null && next < corpus.length) {
      final tokens = resources.reference.span([corpus.words[next].ref]).tokens;
      final opening = tokens.where((t) => !t.optional).take(2);
      if (opening.any((t) => _tail.contains(t.token))) {
        _tail = const {};
        return;
      }
    }
    var f = _mark, gap = 0, last = _mark;
    while (f < end) {
      final c = _frames.best(f);
      if (c == ctcBlank) {
        if (++gap >= config.pauseFrames) break;
      } else if (_tail.contains(c)) {
        gap = 0;
        last = f + 1;
      } else {
        break;
      }
      f++;
    }
    if (f >= end && gap < config.pauseFrames) {
      return; // may still be going: decide when more audio comes
    }
    _mark = last;
    _tail = const {};
  }

  /// A fit is usable if it explains the audio up to its end, or up to a
  /// pause after which the rest is left for the next step.
  bool _usable(_Fit fit, double cost) =>
      fit.cost <= cost &&
      (fit.trailingSpeech <= 4 || fit.pauseAfter >= config.pauseFrames);

  // ---- following ----

  List<QuranMatchEvent>? _follow(
    PhonemeResources resources,
    AcousticFrames window,
    int from,
    bool flush,
  ) {
    final next = (_cursor ?? 0).clamp(0, corpus.length - 1);
    final last = math.min(corpus.length - 1, next + config.lookAhead);
    // Straight on from the expected word…
    final straight = _align(resources, window, next, last, flexible: false);
    List<QuranMatchEvent>? held;
    if (straight != null &&
        straight.prefixSpeech <= 2 &&
        _usable(straight, config.followCost)) {
      final placed = _emit(straight, from, flush);
      // Nothing finished at a pause: try the next word in full below.
      if (placed.isNotEmpty || !flush) return placed;
      held = placed;
    }
    // At a pause nothing more is coming: the expected word, said in full,
    // may account for the speech before it — from where the last word
    // ended (frames the model heard mostly as blanks, like a ghunna, are
    // otherwise passed over as silence).
    // Only within an ayah: its first word is never taken on a loose fit.
    if (flush && corpus.words[next].ref.wordIndex > 0) {
      final start = math.max(
        _frames.start,
        math.min(from, lastPlacedFrame ?? from),
      );
      final w = _frames.view(start, _frames.end);
      final f = _align(
        resources,
        w,
        next,
        next,
        flexible: false,
        complete: true,
      );
      if (f != null &&
          f.prefixSpeech <= 2 &&
          f.trailingSpeech <= 4 &&
          f.coverage >= 0.8 &&
          f.cost <= config.pauseFollowCost) {
        _log('at a pause: ${_fmt(next)} (cost ${f.cost.toStringAsFixed(2)})');
        return _emit(f, start, flush);
      }
    }
    if (held != null) return held;
    // …or a little back (repeat) or ahead (skip), perhaps after something
    // else.
    // Back a few words — or to the start of the previous ayah (across a
    // surah's start too: re-reading the last ayah before going on), at most
    // 40 words back.
    final thisAyah =
        corpus.verseStartPosition(corpus.words[next].verse) ?? next;
    final previousAyah = corpus.verseStartPosition(
      corpus.words[math.max(0, thisAyah - 1)].verse,
    );
    final first = math.max(
      0,
      math.min(
        next - config.lookBack,
        math.max(next - 40, previousAyah ?? next),
      ),
    );
    final near = _align(resources, window, first, last, flexible: true);
    // A skip ahead needs as much evidence as going back: a sound or two that
    // fits a word further on (a basmala's tail as «مَا», the start of «يَلِدْ»
    // as «يُولَدْ») would otherwise mark the words in between skipped.
    final nearOk =
        near != null &&
        _usable(near, config.followCost) &&
        (near.firstWord <= next ||
            near.requiredPlaced >= config.minRepeatSounds);
    // A formula said between ayahs (a surah's basmala, the isti'adha) —
    // also preferred to a skip ahead that fits no better: a slow basmala
    // can pass for the next surah's words a little ahead («…ٱلرَّحِيمِ» as
    // «ٱلْفَلَقِ»), which would mark the words before them skipped.
    if (!nearOk || near.firstWord > next) {
      for (final (a, b) in _formulas) {
        if (b >= first && a <= last) continue; // it is the text here
        final f = _align(resources, window, a, b, flexible: true);
        if (f == null || !_usable(f, config.followCost)) continue;
        final whole =
            f.prefixSpeech <= config.extraFrames &&
            f.coverage >= 0.7 &&
            (!nearOk || f.cost <= near.cost);
        // Under way: part of a long formula (a slow basmala spans several
        // windows), fitting clearly better than the skip.
        final partial =
            nearOk && f.coverage >= 0.25 && f.cost + 0.2 < near.cost;
        if (whole || partial) {
          _log('passed over ${_fmt(a)} formula');
          _mark = from + f.alignedEnd + 1;
          return const [];
        }
      }
    }
    if (nearOk) {
      var fit = near;
      // Going back to words said identically in more than one place nearby
      // («وَإِذَا» opening 2:13, 2:14 and again within 2:14): which one is
      // not known from them alone — wait for the next word, which tells.
      // At a pause nothing more is coming: the nearest.
      if (near.firstWord < next) {
        final others = _sameWordsAt(near, first, next);
        if (others.isNotEmpty) {
          if (!flush) {
            _log(
              'back to ${_fmt(near.firstWord)} or '
              '${others.map(_fmt).join(', ')}: waiting for the next word',
            );
            return const [];
          }
          final nearest = [near.firstWord, ...others].reduce(math.max);
          if (nearest != near.firstWord) {
            final f = _align(resources, window, nearest, last, flexible: true);
            if (f != null && _usable(f, config.followCost)) fit = f;
          }
        }
      }
      return [
        ..._explainPrefix(resources, window, fit, first, last, from),
        ..._emit(fit, from, flush),
      ];
    }
    // Something not the text, then the text again: a wrong word, then the
    // right one — or a restart a few words back. The alignments above must
    // explain the wrong word's sounds too, so nothing fits until it is set
    // aside: try the audio after each gap in the speech.
    final after = _afterUnplaced(
      resources,
      window,
      next,
      first,
      last,
      from,
      flush,
    );
    if (after != null) return after;
    _log(
      'no fit at ${_fmt(next)}: straight '
      '${straight?.cost.toStringAsFixed(2)} prefix ${straight?.prefixSpeech} '
      'trailing ${straight?.trailingSpeech}, near '
      '${near?.cost.toStringAsFixed(2)} from ${near == null ? '-' : _fmt(near.firstWord)} '
      'trailing ${near?.trailingSpeech}',
    );
    return null;
  }

  /// Other places in [first]..[next] where [fit]'s words (all of them, in
  /// order) are the same words — where the audio fits just as well.
  List<int> _sameWordsAt(_Fit fit, int first, int next) {
    final n = fit.lastWord - fit.firstWord + 1;
    String key(int p) => corpus.words[p].key;
    return [
      for (var q = first; q + n - 1 < next + n && q <= next; q++)
        if (q != fit.firstWord &&
            q + n - 1 < corpus.length &&
            [for (var i = 0; i < n; i++) key(q + i)].join(' ') ==
                [for (var i = 0; i < n; i++) key(fit.firstWord + i)].join(' '))
          q,
    ];
  }

  /// The window from a gap in the speech on (a word's worth of speech before
  /// it: [LocalPositionTrackerConfig.extraFrames] to 1.6 s), if that part
  /// follows on from the expected word or goes back a little (a restart):
  /// the speech before the gap is reported as a word not in the text, and
  /// what follows is placed. Longer speech before is left to relocating —
  /// a restart from further back can be text, not a wrong word.
  List<QuranMatchEvent>? _afterUnplaced(
    PhonemeResources resources,
    AcousticFrames window,
    int next,
    int first,
    int last,
    int from,
    bool flush,
  ) {
    var speech = 0, blankRun = 0;
    for (var f = 0; f < window.frames; f++) {
      var arg = 0;
      for (var c = 1; c < window.classes; c++) {
        if (window.at(f, c) > window.at(f, arg)) arg = c;
      }
      if (arg == ctcBlank) {
        blankRun++;
        continue;
      }
      if (speech > 40) return null;
      // Speech resumes after a gap: try from the start of the gap.
      if (blankRun >= 2 && speech >= config.extraFrames) {
        final cut = f - blankRun;
        final rest = window.slice(cut, window.frames - 1);
        final fit = _align(resources, rest, first, last, flexible: true);
        if (fit != null &&
            fit.prefixSpeech <= 2 &&
            _usable(fit, config.followCost) &&
            fit.firstWord <= next &&
            (fit.firstWord == next ||
                fit.requiredPlaced >= config.minRepeatSounds)) {
          _log(
            'not the text, then ${_fmt(fit.firstWord)} '
            '(cost ${fit.cost.toStringAsFixed(2)})',
          );
          _mark = from + cut;
          return [
            if (_emittedMax >= 0)
              const WordHeard(ref: null, heard: '…', similarity: 0),
            ..._emit(fit, from + cut, flush),
          ];
        }
      }
      blankRun = 0;
      speech++;
    }
    return null;
  }

  /// Speech before [fit]'s words: a formula (passed over), words that fit
  /// on their own (a false start: placed, so a correction reads as one), or
  /// something else (an extra word).
  List<QuranMatchEvent> _explainPrefix(
    PhonemeResources resources,
    AcousticFrames window,
    _Fit fit,
    int first,
    int last,
    int from,
  ) {
    if (fit.prefixSpeech < config.extraFrames || fit.start < 4) return const [];
    final prefix = window.slice(0, fit.start - 1);
    for (final (a, b) in _formulas) {
      if (b >= first && a <= last) continue;
      final f = _align(resources, prefix, a, b, flexible: true);
      if (f != null && f.coverage >= 0.7 && f.cost <= config.followCost) {
        _log('passed over ${_fmt(a)} formula');
        return const [];
      }
    }
    final words = _align(resources, prefix, first, last, flexible: true);
    if (words != null &&
        words.cost <= config.followCost &&
        words.requiredPlaced >= 3) {
      final placed = _emit(words, from, true, strict: true);
      if (placed.whereType<WordHeard>().any((h) => h.ref != null)) {
        return placed;
      }
    }
    return [
      if (_emittedMax >= 0)
        const WordHeard(ref: null, heard: '…', similarity: 0),
    ];
  }

  // ---- locating ----

  List<QuranMatchEvent> _locate(
    PhonemeResources resources,
    AcousticFrames window,
    int from,
    bool flush,
  ) {
    final hypothesis = QuranPhonemeIndex.decode(window);
    if (hypothesis.length < config.minLocateSymbols &&
        !(flush && hypothesis.length >= config.minLocateSymbols ~/ 2)) {
      return const [];
    }
    // Candidates from each search area, nearest first.
    final scopes = <(String, int?, int?, double)>[
      if (_hasFocus) ('page', _focusStart - 5, _focusEnd + 5, config.pageCost),
      if (_cursor != null)
        ('nearby', _cursor! - 300, _cursor! + 300, config.nearbyCost),
      ('quran', null, null, config.quranCost),
    ];
    final found = <_Scored>[];
    for (final (area, (scope, lo, hi, limit)) in scopes.indexed) {
      for (final c in resources.index.lookup(
        hypothesis,
        from: lo,
        to: hi,
        limit: scope == 'quran' ? 8 : 4,
      )) {
        if (found.any(
          (f) => c.firstWord <= f.lastWord && c.lastWord >= f.firstWord,
        )) {
          continue; // already found in a nearer area
        }
        final a = _align(
          resources,
          window,
          math.max(0, c.firstWord - 3),
          math.min(corpus.length - 1, c.lastWord + 3),
          flexible: true,
        );
        if (a == null) continue;
        found.add(
          _Scored(a, area, scope, limit, c.firstWord - 3, c.lastWord + 3),
        );
      }
    }
    // Reciters start at an ayah's beginning: off the visible page, a place
    // starting mid-ayah must fit clearly better (Al-Kahf's «ٱلْحَمْدُ لِلَّهِ
    // ٱلَّذِىٓ» also opens the middle of 35:34, near Ya-Sin on screen).
    double rank(_Scored f) =>
        f.alignment.cost +
        (f.area > 0 && corpus.words[f.alignment.firstWord].ref.wordIndex > 0
            ? 0.1
            : 0);
    final fitting = [
      for (final f in found)
        if (_usable(f.alignment, f.limit) &&
            f.alignment.fittedFrames >= config.minLocateFrames)
          f,
    ]..sort((a, b) => rank(a).compareTo(rank(b)));
    if (fitting.isEmpty) {
      final top = found.isEmpty
          ? null
          : found.reduce(
              (a, b) => a.alignment.cost <= b.alignment.cost ? a : b,
            );
      _log(
        'locate: no fit among ${found.length} '
        '(${hypothesis.length} symbols; best '
        '${top == null ? '-' : '${_fmt(top.alignment.firstWord)} ${top.alignment.cost.toStringAsFixed(2)} '
                  'trailing ${top.alignment.trailingSpeech} pause ${top.alignment.pauseAfter} '
                  'fitted ${top.alignment.fittedFrames}'})',
      );
      return const [];
    }
    final best = fitting.first;
    final bestFirst = best.alignment.firstWord;
    final bestLast = best.alignment.lastWord;
    // A formula said before reciting (a surah's basmala, the isti'adha),
    // not the passage it comes from: passed over, and what follows it
    // located on its own.
    final focusEnd = _hasFocus ? _focusEnd : -1;
    for (final (a, b) in _formulas) {
      if (bestFirst >= a &&
          bestFirst <= b &&
          !(_focusStart <= b && focusEnd >= a) &&
          !(_cursor != null && _cursor! >= a && _cursor! <= b + 1)) {
        final fit = best.alignment;
        var end = -1;
        for (var k = 0; k < fit.tokens.length; k++) {
          final p = _positionOf(fit.tokens[k]);
          final s = fit.spans[k];
          if (s != null && p >= a && p <= b) end = math.max(end, s.end);
        }
        if (end < 0) break;
        _log('passed over ${_fmt(a)} formula');
        _mark = from + end + 1;
        return const [];
      }
    }
    // The best fit elsewhere — a different passage, not the same one.
    _Scored? rival;
    for (final f in fitting.skip(1)) {
      if (f.alignment.firstWord <= bestLast &&
          f.alignment.lastWord >= bestFirst) {
        continue;
      }
      rival = f;
      break;
    }
    if (rival != null) {
      final gap = rank(rival) - rank(best);
      final nearer = best.area < rival.area;
      if (gap < config.margin && !(nearer && gap >= 0)) {
        _log(
          'locate: ambiguous ${_fmt(bestFirst)} '
          '${best.alignment.cost.toStringAsFixed(2)} vs '
          '${_fmt(rival.alignment.firstWord)} '
          '${rival.alignment.cost.toStringAsFixed(2)} — waiting',
        );
        return const [];
      }
    }
    final relocated = MatchRelocated(
      from: current,
      to: corpus.words[bestFirst].ref,
      scope: best.scope,
    );
    _locked = true;
    _log(
      'located ${_fmt(bestFirst)}..${_fmt(bestLast)} (${best.scope}, cost '
      '${best.alignment.cost.toStringAsFixed(2)}'
      '${rival == null ? '' : ', next ${rival.alignment.cost.toStringAsFixed(2)}'})',
    );
    return [relocated, ..._emit(best.alignment, from, flush)];
  }

  // ---- alignment ----

  /// Aligns [window] to words [first]..[last]: from the first word, or —
  /// [flexible] — from any of them after unplaced audio; ending anywhere.
  _Fit? _align(
    PhonemeResources resources,
    AcousticFrames window,
    int first,
    int last, {
    required bool flexible,
    bool complete = false,
  }) {
    if (first > last || window.frames == 0) return null;
    final span = resources.reference.span([
      for (var p = first; p <= last; p++) corpus.words[p].ref,
    ]);
    final tokens = span.tokens;
    if (tokens.isEmpty) return null;
    final startAt = <int>{};
    if (flexible) {
      for (var k = 0; k < tokens.length; k++) {
        if (k == 0 || tokens[k - 1].unit != tokens[k].unit) startAt.add(k);
      }
    }
    final a = ctcForcedAlign(
      window,
      [for (final t in tokens) t.token],
      optional: [for (final t in tokens) t.optional || t.unitFinalVowel],
      startAt: flexible ? startAt : null,
      // [complete]: only at the end of a word, not partway through one.
      endAt: {
        for (var k = 0; k < tokens.length; k++)
          if (!complete ||
              k == tokens.length - 1 ||
              tokens[k + 1].word != tokens[k].word)
            k,
      },
    );
    // Per frame, how far below the model's best reading the path is.
    final label = List<int>.filled(window.frames, ctcBlank);
    var start = window.frames, alignedEnd = -1;
    var requiredPlaced = 0, required = 0;
    for (var k = 0; k < tokens.length; k++) {
      final isRequired = !(tokens[k].optional || tokens[k].unitFinalVowel);
      final s = a.spans[k];
      if (s == null) continue;
      if (isRequired) requiredPlaced++;
      start = math.min(start, s.start);
      alignedEnd = math.max(alignedEnd, s.end);
      for (var f = s.start; f <= s.end; f++) {
        label[f] = tokens[k].token;
      }
    }
    if (start == window.frames) return null;
    for (final t in tokens) {
      if (!(t.optional || t.unitFinalVowel)) required++;
    }
    final excess = Float64List(window.frames);
    var prefixSpeech = 0, trailingSpeech = 0, pauseAfter = 0;
    var inPause = true;
    for (var f = 0; f < window.frames; f++) {
      var top = double.negativeInfinity;
      var arg = 0;
      for (var c = 0; c < window.classes; c++) {
        final v = window.at(f, c);
        if (v > top) {
          top = v;
          arg = c;
        }
      }
      // A stretched madd / ghunnah holds blanks between its repeats.
      final fit = stretchableTokens.contains(label[f])
          ? math.max(window.at(f, label[f]), window.at(f, ctcBlank))
          : window.at(f, label[f]);
      excess[f] = top - fit;
      if (f < start && arg != ctcBlank) prefixSpeech++;
      if (f > alignedEnd) {
        if (arg != ctcBlank) {
          trailingSpeech++;
          inPause = false;
        } else if (inPause) {
          pauseAfter++;
        }
      }
    }
    var total = 0.0;
    for (var f = start; f <= alignedEnd; f++) {
      total += excess[f];
    }
    var fitted = 0;
    for (final s in a.spans) {
      if (s != null) fitted += s.end - s.start + 1;
    }
    return _Fit(
      tokens: tokens,
      spans: a.spans,
      excess: excess,
      start: start,
      alignedEnd: alignedEnd,
      cost: total / (alignedEnd - start + 1),
      prefixSpeech: prefixSpeech,
      trailingSpeech: trailingSpeech,
      pauseAfter: pauseAfter,
      fittedFrames: fitted,
      requiredPlaced: requiredPlaced,
      coverage: required == 0 ? 0 : requiredPlaced / required,
      firstWord: _positionOf(tokens[a.spans.indexWhere((s) => s != null)]),
      lastWord: _positionOf(tokens[a.spans.lastIndexWhere((s) => s != null)]),
    );
  }

  int _positionOf(PhoneticToken t) => corpus.positionOf(t.word) ?? 0;

  /// Reports the finished words of [fit] in order. A word is finished when
  /// every sound unit it has a part in is (some words are said as several
  /// units — «يس» is «يا» + «سين» — and some units hold several words).
  ///
  /// Words said again (going back) are believed only if they fit well
  /// ([LocalPositionTrackerConfig.repeatCost]); otherwise that audio is
  /// reported as an extra sound. [strict]: every word must fit as well as a
  /// continuation, or none is placed.
  List<QuranMatchEvent> _emit(
    _Fit fit,
    int from,
    bool flush, {
    bool strict = false,
  }) {
    final tokens = fit.tokens;
    final frames = fit.excess.length;
    // Units in order: (first token, last token).
    final units = <(int, int)>[];
    for (var k = 0; k < tokens.length; k++) {
      if (k == 0 || tokens[k].unit != tokens[k - 1].unit) {
        units.add((k, k));
      } else {
        units[units.length - 1] = (units.last.$1, k);
      }
    }
    // Each word's last token.
    final wordEnd = <int, int>{};
    for (var k = 0; k < tokens.length; k++) {
      wordEnd[_positionOf(tokens[k])] = k;
    }
    final finished = <_Placed>[];
    var started = false;
    final pending = <int>[]; // words begun, not finished
    var pendingStart = frames;
    var pendingCost = 0.0, pendingFrames = 0, pendingSounds = 0;
    for (final (a, b) in units) {
      final aligned = fit.spans.sublist(a, b + 1).any((s) => s != null);
      if (!aligned) {
        if (started) break; // past what has been said
        continue;
      }
      started = true;
      // Finished: every sound that must be said is placed, and the audio
      // goes on past the last of them.
      var complete = true;
      var unitEnd = -1, unitStart = frames;
      for (var k = a; k <= b; k++) {
        final s = fit.spans[k];
        final required = !(tokens[k].optional || tokens[k].unitFinalVowel);
        if (s == null) {
          if (required) complete = false;
          continue;
        }
        if (required) pendingSounds++;
        unitEnd = math.max(unitEnd, s.end);
        unitStart = math.min(unitStart, s.start);
      }
      final laterPlaced =
          b + 1 < tokens.length && fit.spans.skip(b + 1).any((s) => s != null);
      if (!complete ||
          (!laterPlaced && !flush && frames - 1 - unitEnd < config.endMargin)) {
        break;
      }
      for (var f = unitStart; f <= unitEnd; f++) {
        pendingCost += fit.excess[f];
      }
      pendingFrames += unitEnd - unitStart + 1;
      pendingStart = math.min(pendingStart, unitStart);
      for (var k = a; k <= b; k++) {
        final p = _positionOf(tokens[k]);
        if (!pending.contains(p)) pending.add(p);
      }
      // Words ending in this unit are finished.
      final done = [
        for (final p in pending)
          if (wordEnd[p]! <= b) p,
      ];
      if (done.isEmpty) continue;
      finished.add(
        _Placed(
          done,
          _symbols(fit, pendingStart, unitEnd),
          pendingCost / pendingFrames,
          pendingStart,
          unitEnd,
          pendingSounds,
        ),
      );
      pending.removeWhere(done.contains);
      pendingStart = frames;
      pendingCost = 0;
      pendingFrames = 0;
      pendingSounds = 0;
    }
    if (finished.isEmpty) return const [];
    _mark = from + finished.last.end + 1;
    lastPlacedFrame = _mark;
    // The closing sounds of the last word (its last 3 tokens placed).
    final closing = <int>{};
    for (var k = tokens.length - 1; k >= 0 && closing.length < 3; k--) {
      final sp = fit.spans[k];
      if (sp != null && sp.end <= finished.last.end) {
        closing.add(tokens[k].token);
      }
    }
    _tail = closing;
    if (strict && finished.any((w) => w.cost > config.followCost)) {
      _log('unplaced speech at ${from + finished.first.start}');
      return [
        if (_emittedMax >= 0)
          const WordHeard(ref: null, heard: '…', similarity: 0),
      ];
    }
    // Words said again, at the start: believed only if they fit well.
    var again = 0;
    while (again < finished.length &&
        finished[again].words.every(_placedWords.contains)) {
      again++;
    }
    final events = <QuranMatchEvent>[];
    // Leading words that don't fit well are not believed; the repeat is
    // what follows them, if it holds enough sounds.
    var skipTo = 0;
    while (skipTo < again && finished[skipTo].cost > config.repeatCost) {
      skipTo++;
    }
    final believed = finished.sublist(skipTo, again);
    if (believed.isNotEmpty &&
        (believed.fold(0, (n, w) => n + w.sounds) < config.minRepeatSounds ||
            believed.any((w) => w.cost > config.repeatCost))) {
      skipTo = again;
    }
    if (skipTo > 0) {
      _log(
        'not a repeat: '
        '${finished.take(skipTo).expand((w) => w.words).map(_fmt).join(' ')}'
        ' (cost ${finished.take(skipTo).map((w) => w.cost.toStringAsFixed(2)).join(' ')})',
      );
      if (_emittedMax >= 0) {
        events.add(const WordHeard(ref: null, heard: '…', similarity: 0));
      }
    }
    for (final w in finished.skip(skipTo)) {
      final similarity = w.cost >= config.wrongWordCost
          ? 0.4
          : (1 - w.cost / (2 * config.wrongWordCost)).clamp(0.75, 1.0);
      _log(
        'placed ${w.words.map(_fmt).join(' ')} at '
        '${from + w.start}..${from + w.end} "${w.heard}" '
        'cost ${w.cost.toStringAsFixed(2)}',
      );
      for (final p in w.words) {
        events.addAll(_place(p, w.heard, similarity));
        placements.add((
          ref: corpus.words[p].ref,
          start: from + w.start,
          end: from + w.end,
        ));
      }
    }
    return events;
  }

  List<QuranMatchEvent> _place(int p, String heard, double similarity) {
    final events = <QuranMatchEvent>[];
    final previous = _current;
    if (previous != null && p > previous + 1) {
      for (var s = previous + 1; s < p; s++) {
        if (s > _emittedMax) events.add(WordSkipped(corpus.words[s].ref));
      }
    }
    if (p <= _emittedMax) events.add(WordRepeated(corpus.words[p].ref));
    final ref = corpus.words[p].ref;
    events
      ..add(WordHeard(ref: ref, heard: heard, similarity: similarity))
      ..add(CurrentWord(ref, confidence: similarity));
    if (similarity >= 0.75) {
      events.add(WordConfirmed(ref, similarity: similarity));
    }
    _current = p;
    _cursor = p + 1;
    _emittedMax = math.max(_emittedMax, p);
    // Going back: the words after it are ahead again (said once more, they
    // continue the recitation rather than repeat it).
    _placedWords
      ..removeWhere((q) => q > p)
      ..add(p);
    return events;
  }

  String _symbols(_Fit fit, int from, int to) {
    final out = StringBuffer();
    for (var k = 0; k < fit.tokens.length; k++) {
      final s = fit.spans[k];
      if (s != null && s.start >= from && s.end <= to) {
        out.write(fit.tokens[k].symbol);
      }
    }
    return out.toString();
  }

  String _fmt(int p) {
    final r = corpus.words[p.clamp(0, corpus.length - 1)].ref;
    return '${r.ayahId ~/ 1000}:${r.ayahId % 1000}:${r.wordIndex + 1}';
  }

  void _log(String line) => log?.call(line);
}

class _Fit {
  const _Fit({
    required this.tokens,
    required this.spans,
    required this.excess,
    required this.start,
    required this.alignedEnd,
    required this.cost,
    required this.prefixSpeech,
    required this.trailingSpeech,
    required this.pauseAfter,
    required this.fittedFrames,
    required this.requiredPlaced,
    required this.coverage,
    required this.firstWord,
    required this.lastWord,
  });

  final List<PhoneticToken> tokens;
  final List<FrameSpan?> spans;

  /// Per window frame, how much less likely its assigned label is than the
  /// model's best class.
  final Float64List excess;

  /// The first and last frame on a sound of the words.
  final int start, alignedEnd;

  /// Mean [excess] over [start]..[alignedEnd].
  final double cost;

  /// Frames where the model heard speech before [start] / after
  /// [alignedEnd]; silent frames right after [alignedEnd].
  final int prefixSpeech, trailingSpeech, pauseAfter;

  /// Frames on a sound of the words; required sounds placed, and their
  /// share of all the words' required sounds.
  final int fittedFrames, requiredPlaced;
  final double coverage;

  /// Corpus positions of the first and last word reached.
  final int firstWord, lastWord;
}

/// Finished words of one alignment: their sounds' frames and fit.
class _Placed {
  const _Placed(
    this.words,
    this.heard,
    this.cost,
    this.start,
    this.end,
    this.sounds,
  );

  final List<int> words;
  final String heard;
  final double cost;
  final int start, end, sounds;
}

class _Scored {
  const _Scored(
    this.alignment,
    this.area,
    this.scope,
    this.limit,
    this.firstWord,
    this.lastWord,
  );

  final _Fit alignment;

  /// Search area: 0 nearest; its name and cost limit.
  final int area;
  final String scope;
  final double limit;
  final int firstWord, lastWord;
}

/// The frames not yet placed (and a little before), on the stream's
/// frame timeline.
class _FrameBuffer {
  int start = 0;
  int _count = 0;
  int classes = 0;
  Duration frameDuration = const Duration(milliseconds: 40);
  Float32List _data = Float32List(0);

  int get end => start + _count;

  void add(TimedAcousticFrames chunk) {
    final f = chunk.frames;
    if (_count == 0) {
      start = chunk.start;
      classes = f.classes;
      frameDuration = f.frameDuration;
    }
    final skip = end - chunk.start; // overlap already held
    if (skip < 0) {
      // A gap (frames dropped upstream): start afresh after it.
      _count = 0;
      start = chunk.start;
      return add(chunk);
    }
    final added = f.frames - skip;
    if (added <= 0) return;
    final need = (_count + added) * classes;
    if (need > _data.length) {
      final grown = Float32List(math.max(need, _data.length * 2));
      grown.setRange(0, _count * classes, _data);
      _data = grown;
    }
    _data.setRange(_count * classes, need, f.logProbs, skip * classes);
    _count += added;
  }

  void dropBefore(int frame) {
    final drop = (frame - start).clamp(0, _count);
    if (drop == 0) return;
    _data.setRange(0, (_count - drop) * classes, _data, drop * classes);
    _count -= drop;
    start += drop;
  }

  double _at(int frame, int c) => _data[(frame - start) * classes + c];

  int best(int frame) {
    var arg = 0;
    for (var c = 1; c < classes; c++) {
      if (_at(frame, c) > _at(frame, arg)) arg = c;
    }
    return arg;
  }

  bool isBlank(int frame) {
    final blank = _at(frame, ctcBlank);
    for (var c = 1; c < classes; c++) {
      if (_at(frame, c) > blank) return false;
    }
    return true;
  }

  int speechFrames(int from, int to) {
    var n = 0;
    for (var f = from; f < to; f++) {
      if (!isBlank(f)) n++;
    }
    return n;
  }

  AcousticFrames view(int from, int to) => AcousticFrames(
    frames: to - from,
    classes: classes,
    logProbs: Float32List.fromList(
      Float32List.sublistView(
        _data,
        (from - start) * classes,
        (to - start) * classes,
      ),
    ),
    frameDuration: frameDuration,
  );
}
