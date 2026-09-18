/// Tahfeez's icon size scale.
///
/// Centralized so icons across app bars, list rows, chips, and action bars
/// stay visually consistent instead of each screen picking its own size.
abstract final class TahfeezIconSize {
  /// Inline with dense text (metadata rows, chip leading icons).
  static const double sm = 16;

  /// The default for most icon buttons and list-row leading icons.
  static const double md = 20;

  /// App bar actions, primary verse-action-bar icons.
  static const double lg = 24;

  /// Empty/error state illustrations, prominent feature icons.
  static const double xl = 32;
}
