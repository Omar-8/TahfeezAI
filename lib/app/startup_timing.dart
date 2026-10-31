import 'package:flutter/foundation.dart';

final _clock = Stopwatch();

/// The start's phases, timed from [bootstrap]'s first line, in the log
/// (`startup: 812 ms databases: quran`): how long the first launch takes
/// and where. Debug and profile builds only.
void startupMark(String what) {
  if (kReleaseMode) return;
  if (!_clock.isRunning) _clock.start();
  debugPrint('startup: ${_clock.elapsedMilliseconds} ms $what');
}
