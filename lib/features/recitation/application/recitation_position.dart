import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_refs.dart';

/// Where the reciter is in the Quran: the word the Hifz test expects next
/// (or, the test just finished, its last word); `null` while no test runs.
///
/// Published by the Hifz controller and read by the acoustic verifier —
/// its own provider so the two don't depend on each other (the Hifz
/// controller also listens to the verifier's results).
class RecitationPositionController extends Notifier<WordRef?> {
  @override
  WordRef? build() => null;

  void set(WordRef? position) {
    if (position != state) state = position;
  }
}

final recitationPositionProvider =
    NotifierProvider<RecitationPositionController, WordRef?>(
      RecitationPositionController.new,
    );

/// Which pass over the recitation the Hifz test is on: `0` at a session's
/// start, one more each time a loop starts its range (or ayah) again — so
/// pronunciation verdicts are told apart from the same words' verdicts in
/// an earlier repetition.
class RecitationPassController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int pass) {
    if (pass != state) state = pass;
  }
}

final recitationPassProvider = NotifierProvider<RecitationPassController, int>(
  RecitationPassController.new,
);
