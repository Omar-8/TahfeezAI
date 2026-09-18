/// Tahfeez's constrained content widths.
///
/// `docs/DESIGN_DIRECTION.md` explicitly warns against stretching phone
/// layouts across large screens and asks for "a constrained reading width"
/// and "optional side panel" on desktop/web. These widths are the single
/// source of truth for that constraint, used by
/// `TahfeezResponsiveScaffold` and, later, the Reader/Mushaf screens.
abstract final class TahfeezContentWidth {
  /// The maximum width a single column of reading content (translation
  /// text, settings lists, a single Mushaf page) should ever stretch to,
  /// regardless of viewport width — prevents the "phone layout stretched
  /// across a monitor" anti-pattern.
  static const double maxReading = 720;

  /// A narrower cap for short-form content (a dialog's body text, a form).
  static const double maxForm = 480;

  /// The width of an optional secondary panel on wide layouts (e.g. a
  /// tafsir/translation/notes side panel next to the reading column).
  static const double sidePanel = 360;
}
