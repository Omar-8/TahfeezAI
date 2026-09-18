import 'package:flutter/widgets.dart';

/// Tahfeez's responsive width classes.
///
/// Matches `docs/DESIGN_DIRECTION.md`'s three-tier responsive guidance
/// (phone / tablet / desktop-web), each with a materially different layout
/// intent (compact nav + single-page Mushaf on phone, up to an optional
/// side panel and two-page Mushaf on wider surfaces). Feature milestones
/// should branch on [TahfeezBreakpoint] rather than raw width comparisons or
/// platform checks, so the thresholds stay centralized and consistent.
enum TahfeezBreakpoint {
  /// Compact navigation, single-page Mushaf, bottom sheets for secondary
  /// actions.
  phone,

  /// Room for a navigation rail and an optional two-page Mushaf.
  tablet,

  /// Adaptive navigation, a constrained reading column, and an optional side
  /// panel for tafsir/translation/notes.
  desktop;

  /// Width, in logical pixels, below which the [phone] breakpoint applies.
  static const double phoneMaxWidth = 600;

  /// Width, in logical pixels, below which the [tablet] breakpoint applies
  /// (at or above [phoneMaxWidth]).
  static const double tabletMaxWidth = 1024;

  static TahfeezBreakpoint fromWidth(double width) {
    if (width < phoneMaxWidth) return TahfeezBreakpoint.phone;
    if (width < tabletMaxWidth) return TahfeezBreakpoint.tablet;
    return TahfeezBreakpoint.desktop;
  }

  /// Convenience accessor: `TahfeezBreakpoint.of(context)`.
  static TahfeezBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isPhone => this == TahfeezBreakpoint.phone;
  bool get isTablet => this == TahfeezBreakpoint.tablet;
  bool get isDesktop => this == TahfeezBreakpoint.desktop;

  /// True from [tablet] upward — the point at which a navigation rail
  /// becomes viable instead of a bottom nav bar, per
  /// `docs/DESIGN_DIRECTION.md`'s responsive guidance.
  bool get isAtLeastTablet => this != TahfeezBreakpoint.phone;
}
