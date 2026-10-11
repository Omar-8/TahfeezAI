import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_refs.dart';
import 'acoustic_verification_controller.dart';
import 'recitation_session_controller.dart';

/// With nothing being checked this long after the pause, no check is
/// coming (no words of it were placed).
const _settleNothing = Duration(milliseconds: 1500);
const _settleMax = Duration(seconds: 4);

/// The end of a recited part (a Follow along turn, a loop's pass): pauses
/// the microphone, so what was heard is checked at once rather than after
/// the reciter is heard to stop, and waits for the pronunciation check of
/// [lastAyah] ([pass]'s, confirmed by its ayah's check) — at most a few
/// seconds. Returns the verdicts then; none without the check.
Future<Map<WordRef, AcousticWordResult>> settleAcousticCheck(
  Ref ref, {
  required int lastAyah,
  required int pass,
}) async {
  // Out of the caller's update, then the microphone off.
  await Future<void>.delayed(Duration.zero);
  ref.read(recitationSessionControllerProvider.notifier).pause();
  if (!ref.exists(acousticVerificationControllerProvider)) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const {};
  }
  AcousticVerificationState acoustic() =>
      ref.read(acousticVerificationControllerProvider);
  final started = DateTime.now();
  while (ref.mounted) {
    final now = acoustic();
    final waited = DateTime.now().difference(started);
    final checked = now.words.entries.any(
      (e) =>
          e.key.ayahId == lastAyah &&
          e.value.pass == pass &&
          !e.value.provisional,
    );
    if (now.pending == 0 &&
        (checked || waited >= _settleNothing || !now.active)) {
      break;
    }
    if (waited >= _settleMax) break;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return ref.mounted ? acoustic().words : const {};
}

/// Whether [words] hold a pronunciation mistake of [pass] in one of
/// [ayahIds].
bool hasPronunciationMistake(
  Map<WordRef, AcousticWordResult> words, {
  required Set<int> ayahIds,
  required int pass,
}) => words.entries.any(
  (e) =>
      ayahIds.contains(e.key.ayahId) &&
      e.value.pass == pass &&
      e.value.isMistake,
);
