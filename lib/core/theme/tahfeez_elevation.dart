/// Tahfeez's elevation scale.
///
/// `docs/DESIGN_DIRECTION.md` explicitly asks to avoid "excessive shadows"
/// and prefers "restrained elevation" and "low-contrast boundaries" —
/// Tahfeez leans on borders/tonal surfaces for separation far more than on
/// shadow depth. This scale is deliberately shallow: nothing in the app
/// should need more than [high].
abstract final class TahfeezElevation {
  /// Flat — the default for cards and list rows, which separate themselves
  /// with a tonal surface color and/or a hairline border instead.
  static const double none = 0;

  /// A hint of lift for a pressed/hovered interactive surface.
  static const double low = 1;

  /// App bars once content has scrolled under them, and other surfaces that
  /// need to read as "above" content without a hard shadow.
  static const double medium = 3;

  /// Reserved for genuinely floating surfaces (a modal sheet's drag handle
  /// area, a floating mini-player). Nothing in Tahfeez should exceed this.
  static const double high = 6;
}
