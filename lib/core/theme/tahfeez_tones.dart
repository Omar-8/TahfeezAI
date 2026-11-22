import 'package:flutter/material.dart';

/// Tones the [ColorScheme] has no slot for, worked out from it (so the
/// warm and sepia papers get their own).
extension TahfeezTones on ColorScheme {
  /// The empty part of a progress bar or ring, a calendar's empty day: in
  /// light mode a step deeper than [surfaceContainerHighest], which hardly
  /// showed on the light glass (owner, 2026-11-21: Progress's ring).
  Color get progressTrack => brightness == Brightness.light
      ? Color.lerp(surfaceContainerHighest, onSurfaceVariant, 0.2)!
      : surfaceContainerHighest;

  /// A part only partly there (Progress's "marked, not recited yet"): solid,
  /// between [progressTrack] and [primary] — not [primary] see-through,
  /// which on the light glass looked like the track.
  Color get progressPartial => brightness == Brightness.light
      ? Color.lerp(progressTrack, primary, 0.42)!
      : primary.withValues(alpha: 0.35);
}
