import 'package:flutter/widgets.dart';

/// Tahfeez's responsive width classes.
///
/// Matches `docs/DESIGN_DIRECTION.md`'s three-tier responsive guidance
/// (phone / tablet / desktop-web), each with a materially different layout
/// intent (compact nav + single-page Mushaf on phone, up to an optional
/// side panel and two-page Mushaf on wider surfaces). Feature milestones
/// should branch on [AppBreakpoint] rather than raw width comparisons or
/// platform checks, so the thresholds stay centralized and consistent.
enum AppBreakpoint {
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

  static AppBreakpoint fromWidth(double width) {
    if (width < phoneMaxWidth) return AppBreakpoint.phone;
    if (width < tabletMaxWidth) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  /// Convenience accessor: `AppBreakpoint.of(context)`.
  static AppBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}
