import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quran_audio_player.dart';

/// The sleep timer's choices: minutes, or the end of the ayah playing.
const sleepTimerMinutes = [15, 30, 45, 60];

/// A sleep timer set: listening pauses at [endsAt], or — [afterAyah] —
/// once the ayah playing when it was set has finished.
@immutable
class SleepTimerState {
  const SleepTimerState.at(DateTime this.endsAt, this.minutes)
    : afterAyah = false,
      _index = null;

  const SleepTimerState._afterAyah(int index)
    : endsAt = null,
      minutes = null,
      afterAyah = true,
      _index = index;

  final DateTime? endsAt;

  /// The minutes chosen (for showing the choice).
  final int? minutes;
  final bool afterAyah;

  /// Its place in the play order (a repetition of the same ayah is the
  /// next one).
  final int? _index;
}

/// Pauses the reciter after a while (or at the end of the ayah playing) —
/// for listening at night. Paused, not stopped: Play resumes where it
/// was. Ends with listening: stopping (or finishing) the recitation clears
/// it.
class SleepTimer extends Notifier<SleepTimerState?> {
  Timer? _timer;

  /// For tests: the time now.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  SleepTimerState? build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(quranAudioPlayerProvider, (_, playing) {
      final s = state;
      if (s == null) return;
      // Listening over: nothing left to pause.
      if (playing == null || playing.isWord) {
        cancel();
      } else if (s.afterAyah &&
          playing.index != s._index &&
          // (Its translation, read after it, is still this ayah.)
          !playing.isTranslation) {
        _fire();
      }
    });
    return null;
  }

  /// Pauses in [minutes] minutes.
  void setMinutes(int minutes) {
    _timer?.cancel();
    final duration = Duration(minutes: minutes);
    _timer = Timer(duration, _fire);
    state = SleepTimerState.at(clock().add(duration), minutes);
  }

  /// Pauses once the ayah playing now has finished (nothing playing:
  /// nothing to wait for).
  void setAfterAyah() {
    final playing = ref.read(quranAudioPlayerProvider);
    if (playing == null || playing.isWord) return;
    _timer?.cancel();
    state = SleepTimerState._afterAyah(playing.index);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  void _fire() {
    cancel();
    unawaited(ref.read(quranAudioPlayerProvider.notifier).pause());
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimer, SleepTimerState?>(
  SleepTimer.new,
);
