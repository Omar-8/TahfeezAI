import 'quran_stream_matcher.dart';

/// Follows the reciter through the Quran and reports each word heard
/// ([QuranMatchEvent]s, chiefly [WordHeard]). Two implementations share
/// these semantics: [QuranStreamMatcher] (from recognized text — the
/// Google/Web Speech path) and `LocalQuranPositionTracker` (from the
/// on-device acoustic model's frames — no text, no network). Hifz consumes
/// only the events, so either can drive it.
abstract interface class RecitationPositionMatcher {
  /// Where recitation is expected to begin — a hint, unless [trustAnchor]:
  /// then recitation starts exactly there. Resets all state.
  void start({int? anchor, bool trustAnchor = false});

  /// The positions shown on screen: searched first when locating — with
  /// [only], the only ones searched (the reciter is expected on them).
  void setFocus(int start, int end, {bool only = false});

  /// Emits what is still held back; call when recitation pauses or stops.
  List<QuranMatchEvent> flush();
}
