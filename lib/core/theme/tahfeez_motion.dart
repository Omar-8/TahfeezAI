import 'package:flutter/animation.dart';

/// Tahfeez's motion tokens.
///
/// `docs/DESIGN_DIRECTION.md` asks for motion that is "subtle and
/// meaningful" — sheet transitions, selection feedback, page movement,
/// memorization reveal, AI listening transitions, progress changes — and
/// explicitly warns against "ornamental motion around Quran text."
/// Durations/curves are centralized here so every future animation reads as
/// part of one coherent motion language rather than a per-widget guess.
abstract final class TahfeezMotionDuration {
  /// Micro-interactions: a chip selecting, an icon toggling.
  static const fast = Duration(milliseconds: 120);

  /// The default for most transitions: sheet open/close, tab switches.
  static const medium = Duration(milliseconds: 220);

  /// Larger movements: page transitions, a memorization reveal animating
  /// across a whole verse.
  static const slow = Duration(milliseconds: 360);
}

abstract final class TahfeezMotionCurves {
  /// The default for entrances and most UI motion.
  static const standard = Curves.easeOutCubic;

  /// For exits/dismissals — slightly quicker to leave than to arrive.
  static const exit = Curves.easeInCubic;

  /// For emphasis moments worth a little bounce (e.g. a completed
  /// memorization session) — used sparingly, never on Quran text itself.
  static const emphasized = Curves.easeOutBack;
}
