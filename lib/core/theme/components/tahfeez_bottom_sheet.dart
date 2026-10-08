import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_spacing.dart';

/// Tracks whether a Tahfeez modal bottom sheet is currently open, plus a
/// short cooldown just after one closes. Flutter Web's platform-view
/// compositing does not reliably stop a native DOM listener on an
/// underlying platform view (e.g. Quran Engine's Mushaf-page `<canvas>`,
/// `quran_engine_web_bridge.dart`) from also receiving the same physical
/// click that opens or dismisses a Flutter-painted overlay above it — a
/// real, reproduced bug, not a theoretical one: selecting a Mushaf
/// appearance option (or dismissing the sheet afterward) could also
/// register as a word tap on the page underneath and pop open the
/// word-detail sheet unintentionally. [isActive] is checked by that
/// canvas click listener before it acts on a click.
class TahfeezModalSheetActivity {
  TahfeezModalSheetActivity._();

  static int _openCount = 0;
  static DateTime? _lastClosedAt;

  /// Long enough to cover the same click event's dispatch to an
  /// underlying platform view, short enough that a deliberate word tap
  /// immediately after closing a sheet still works normally.
  static const _cooldown = Duration(milliseconds: 350);

  static bool get isActive {
    if (_openCount > 0) return true;
    final closedAt = _lastClosedAt;
    return closedAt != null && DateTime.now().difference(closedAt) < _cooldown;
  }

  static void _opened() => _openCount++;

  static void _closed() {
    _openCount = _openCount > 0 ? _openCount - 1 : 0;
    _lastClosedAt = DateTime.now();
  }
}

/// Constraints keeping a modal sheet opened from [context] below the app
/// bar of the screen it was opened from (its nearest [Scaffold]'s, status
/// bar included): as tall as its content, never over the screen's header.
/// Without an app bar, below the status bar.
BoxConstraints sheetBelowAppBar(BuildContext context) {
  final view = View.of(context);
  final screen = view.physicalSize.height / view.devicePixelRatio;
  final top =
      Scaffold.maybeOf(context)?.appBarMaxHeight ??
      view.padding.top / view.devicePixelRatio;
  return BoxConstraints(maxHeight: math.max(0, screen - top));
}

/// Shows a Tahfeez modal bottom sheet with a consistent drag handle, header,
/// and safe-area padding — below the app bar ([sheetBelowAppBar]) unless
/// [constraints] say otherwise.
///
/// `docs/DESIGN_DIRECTION.md` keeps "bottom-sheet interaction for secondary
/// actions" as a KEEP-worthy pattern from the reference app
/// (`docs/reference/18_VISUAL_REFERENCE_NOTES.md` §4) — this is Tahfeez's
/// own implementation of that pattern, used for verse options, filters,
/// and any other secondary/contextual action sheet.
Future<T?> showTahfeezModalBottomSheet<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
}) {
  TahfeezModalSheetActivity._opened();
  final result = showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: constraints ?? sheetBelowAppBar(context),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: TahfeezSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(TahfeezSpacing.xs),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: TahfeezSpacing.md,
                  left: TahfeezSpacing.md,
                  right: TahfeezSpacing.md,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
  result.whenComplete(TahfeezModalSheetActivity._closed);
  return result;
}
