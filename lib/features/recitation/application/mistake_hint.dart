import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_word_overlay.dart' show compareWordRefs;
import 'recitation_session_controller.dart';

/// A sure mistake to hint at above its word ([word]), with [more] others
/// found with it (an ayah's check flags several at once); [id] tells two
/// hints on the same word apart.
typedef MistakeHint = ({WordRef word, int more, int id});

/// The mistake hint shown while reciting (owner, 2026-11-16): the words a
/// mistake alert is given for ([report]) — those found together, the first
/// in reading order with the count of the others. A hint shown stays at
/// least [minShown] before the next replaces it (no flicker when mistakes
/// come one after another). None when no recitation runs.
class MistakeHintController extends Notifier<MistakeHint?> {
  static const minShown = Duration(milliseconds: 1200);

  final _pending = <WordRef>{};
  var _scheduled = false;
  var _id = 0;
  DateTime? _shownAt;
  Timer? _later;

  @override
  MistakeHint? build() {
    ref.onDispose(() => _later?.cancel());
    ref.listen(recitationSessionControllerProvider.select((s) => s.isActive), (
      _,
      active,
    ) {
      if (active) return;
      _pending.clear();
      _later?.cancel();
      state = null;
    });
    return null;
  }

  /// Mistakes on [words], sure (alerted): hinted together.
  void report(Iterable<WordRef> words) {
    _pending.addAll(words);
    if (_pending.isEmpty || _scheduled) return;
    _scheduled = true;
    // (Those of one check arrive one by one in the same moment.)
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _scheduled = false;
    if (!ref.mounted || _pending.isEmpty) return;
    final shownAt = _shownAt;
    final wait = shownAt == null
        ? Duration.zero
        : minShown - DateTime.now().difference(shownAt);
    if (state != null && wait > Duration.zero) {
      _later?.cancel();
      _later = Timer(wait, _flush);
      return;
    }
    final words = _pending.toList()..sort(compareWordRefs);
    _pending.clear();
    _shownAt = DateTime.now();
    state = (word: words.first, more: words.length - 1, id: ++_id);
  }
}

final mistakeHintProvider =
    NotifierProvider<MistakeHintController, MistakeHint?>(
      MistakeHintController.new,
    );
