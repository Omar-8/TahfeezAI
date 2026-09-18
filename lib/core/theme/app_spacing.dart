/// Tahfeez's spacing scale.
///
/// `docs/DESIGN_DIRECTION.md` asks for "a consistent spacing scale rather
/// than arbitrary padding values" and for a slightly more spacious, less
/// cramped feel than the reference app. This scale is the single source of
/// truth for gaps/padding across the app; widgets should reference these
/// constants instead of inlining raw numbers.
abstract final class AppSpacing {
  /// 4dp — tight inline gaps (e.g. between an icon and its label).
  static const double xs = 4;

  /// 8dp — compact internal padding.
  static const double sm = 8;

  /// 12dp — default gap between related inline elements.
  static const double smPlus = 12;

  /// 16dp — default card/section padding.
  static const double md = 16;

  /// 24dp — spacing between distinct sections on a screen.
  static const double lg = 24;

  /// 32dp — generous separation for major page regions.
  static const double xl = 32;

  /// 48dp — page-level top/bottom breathing room on larger screens.
  static const double xxl = 48;
}

/// Card/sheet corner radii.
///
/// `docs/DESIGN_DIRECTION.md` calls for "cards around 16-20 logical pixels
/// radius" — softer and more rounded than the reference app.
abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}
