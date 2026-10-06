import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/matching/quran_stream_matcher.dart';
import '../../../ai/matching/quran_word_corpus.dart';
import '../../../ai/speech/live_quran_recognizer.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/mushaf_hide_mode.dart' show firstVisiblePage;
import '../../mushaf/application/mushaf_page_verses.dart';
import 'live_recognition_controller.dart';
import 'mushaf_recitation_target.dart';
import 'recitation_session_controller.dart';

/// Every canonical word of the Quran in reading order, built once from the
/// Uthmani words in the local dataset (the only script it ships).
final quranWordCorpusProvider = FutureProvider<QuranWordCorpus>((ref) async {
  final words = await ref
      .watch(quranRepositoryProvider)
      .getAllWordsForScript(defaultQuranScriptCode);
  return QuranWordCorpus.fromWords([
    for (final w in words)
      (
        ref: (ayahId: w.ayahId, wordIndex: w.wordIndex),
        // Stable ayah id = chapterNo * 1000 + verseNo (QuranRepository).
        verse: (chapterNo: w.ayahId ~/ 1000, verseNo: w.ayahId % 1000),
        text: w.text,
      ),
  ]);
});

class QuranMatchState {
  const QuranMatchState({
    this.ready = false,
    this.current,
    this.confidence = 0,
    this.recentEvents = const [],
    this.lastLog,
  });

  /// The corpus is loaded and matching can run.
  final bool ready;
  final WordRef? current;
  final double confidence;

  /// The latest few events, newest last — diagnostics only.
  final List<String> recentEvents;
  final String? lastLog;

  QuranMatchState copyWith({
    bool? ready,
    WordRef? current,
    double? confidence,
    List<String>? recentEvents,
    String? lastLog,
  }) => QuranMatchState(
    ready: ready ?? this.ready,
    current: current ?? this.current,
    confidence: confidence ?? this.confidence,
    recentEvents: recentEvents ?? this.recentEvents,
    lastLog: lastLog ?? this.lastLog,
  );
}

/// Milestone R3: turns live recognition transcripts into canonical
/// [WordRef] positions with [QuranStreamMatcher], starting each session at
/// the visible Mushaf page and following the page the reader turns to.
///
/// [events] re-publishes the matcher's events for later milestones; nothing
/// is scored or highlighted yet.
class QuranMatchController extends Notifier<QuranMatchState> {
  QuranStreamMatcher? _matcher;
  QuranWordCorpus? _corpus;
  StreamSubscription<LiveRecognitionEvent>? _recognition;
  final _out = StreamController<QuranMatchEvent>.broadcast();
  String? _sessionId;
  bool _listening = false;

  Stream<QuranMatchEvent> get events => _out.stream;

  @override
  QuranMatchState build() {
    ref.onDispose(() {
      unawaited(_recognition?.cancel());
      unawaited(_out.close());
    });
    ref.listen(
      quranWordCorpusProvider,
      (_, next) => next.whenData(_onCorpus),
      fireImmediately: true,
    );
    ref.listen(
      recitationSessionControllerProvider,
      (_, next) => _onSession(next),
      fireImmediately: true,
    );
    ref.listen(mushafRecitationTargetProvider, (_, _) => _updateFocus());
    ref.listen(mushafPageVersesProvider, (_, _) => _updateFocus());
    ref.listen(fullBleedContentProvider, (_, _) => _updateFocus());
    final recognition = ref.watch(liveRecognitionControllerProvider.notifier);
    _recognition = recognition.events.listen(_onRecognition);
    return const QuranMatchState();
  }

  void _onCorpus(QuranWordCorpus corpus) {
    _corpus = corpus;
    _matcher = QuranStreamMatcher(corpus, log: _log);
    state = state.copyWith(ready: true);
    _restart();
  }

  void _onSession(RecitationSessionState session) {
    final id = session.session?.id;
    if (id != null && id != _sessionId) {
      _sessionId = id;
      _restart();
    }
    final listening = session.phase == RecitationPhase.listening;
    // Paused or stopped: emit the word held back from the last segment.
    if (_listening && !listening) _publish(_matcher?.flush() ?? const []);
    _listening = listening;
  }

  /// Starts matching over, at the first word of the visible page.
  void _restart() {
    final matcher = _matcher;
    if (matcher == null) return;
    final focus = _visibleRange();
    matcher.start(anchor: focus?.$1);
    if (focus != null) matcher.setFocus(focus.$1, focus.$2);
    state = QuranMatchState(ready: true);
  }

  void _updateFocus() {
    final focus = _visibleRange();
    if (focus != null) _matcher?.setFocus(focus.$1, focus.$2);
  }

  /// Corpus positions of the visible page (both pages of a spread).
  (int, int)? _visibleRange() {
    final corpus = _corpus;
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (corpus == null || location is! QuranLocationPage) return null;
    final spans = ref.read(mushafPageVersesProvider);
    final spread = ref.read(fullBleedContentProvider);
    final page = firstVisiblePage(location.pageNumber, spread: spread);
    final first = spans[page];
    if (first == null) return null;
    final last = (spread ? spans[page + 1] : null) ?? first;
    final start = corpus.verseStartPosition(first.first);
    final end = corpus.verseEndPosition(last.last);
    return start == null || end == null ? null : (start, end);
  }

  void _onRecognition(LiveRecognitionEvent event) {
    final matcher = _matcher;
    if (matcher == null) return;
    _publish(switch (event) {
      LivePartialTranscript(:final text) => matcher.onPartial(text),
      LiveFinalTranscript(:final text) => matcher.onFinal(text),
      _ => const <QuranMatchEvent>[],
    });
  }

  void _publish(List<QuranMatchEvent> out) {
    final matcher = _matcher;
    if (out.isEmpty || matcher == null) return;
    out.forEach(_out.add);
    final recent = [
      ...state.recentEvents,
      for (final e in out)
        if (e is! WordHeard) '$e',
    ];
    state = state.copyWith(
      current: matcher.current,
      confidence: matcher.confidence,
      recentEvents: recent.length > 6
          ? recent.sublist(recent.length - 6)
          : recent,
    );
  }

  void _log(String line) {
    if (!kReleaseMode) debugPrint('QuranMatch: $line');
    state = state.copyWith(lastLog: line);
  }
}

final quranMatchControllerProvider =
    NotifierProvider.autoDispose<QuranMatchController, QuranMatchState>(
      QuranMatchController.new,
    );
