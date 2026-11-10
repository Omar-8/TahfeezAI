import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_content_widths.dart';
import '../tahfeez_motion.dart';

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

/// Counts every sheet, dialog and menu on the navigator it observes (the
/// app's root one, where they all open) for [TahfeezModalSheetActivity]
/// — however each was opened, not only through
/// [showTahfeezModalBottomSheet].
class TahfeezPopupObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) TahfeezModalSheetActivity._opened();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) TahfeezModalSheetActivity._closed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) TahfeezModalSheetActivity._closed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute) TahfeezModalSheetActivity._closed();
    if (newRoute is PopupRoute) TahfeezModalSheetActivity._opened();
  }
}

/// How far from the screen's top a sheet opened now may reach at most:
/// something kept in view above sheets while it is up (the guide's card on
/// its steps to try on the page, whose sheets open below it). 0: nothing.
double sheetTopFloor = 0;

/// Constraints keeping a modal sheet opened from [context] below the app
/// bar of the screen it was opened from (its nearest [Scaffold]'s): as tall
/// as its content, never over the screen's header. Without an app bar,
/// below the status bar. For a sheet on the root navigator (the whole
/// screen's height), as [showTahfeezModalBottomSheet] opens them.
BoxConstraints sheetBelowAppBar(BuildContext context) {
  final view = View.of(context);
  final screen = view.physicalSize.height / view.devicePixelRatio;
  var top = view.padding.top / view.devicePixelRatio;
  final scaffold = Scaffold.maybeOf(context);
  final box = scaffold?.context.findRenderObject();
  final appBar = scaffold?.appBarMaxHeight;
  if (box is RenderBox && box.hasSize && appBar != null) {
    // Where the app bar's bottom is on screen (the scaffold may sit inside
    // a shell, below other bars).
    top = math.max(top, box.localToGlobal(Offset.zero).dy + appBar);
  }
  top = math.max(top, sheetTopFloor);
  return BoxConstraints(
    maxHeight: math.max(0, screen - top),
    maxWidth: webSheetMaxWidth(context),
  );
}

/// In a wide browser window, a sheet is no wider than the reading column
/// (the Quran list's width), not the whole window; a phone (its browser
/// too) and the apps keep full-width sheets.
double webSheetMaxWidth(BuildContext context) =>
    isWideWebWindow(context) ? TahfeezContentWidth.maxReading : double.infinity;

/// A browser window wide enough for the wide-window layout ([webWideFrom]);
/// a phone's browser, and the apps, are not.
bool isWideWebWindow(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= webWideFrom;

/// A browser window's width from which its wide-window layout applies.
const webWideFrom = 840.0;

/// Shows a Tahfeez modal bottom sheet with a consistent drag handle, header,
/// and safe-area padding — below the app bar ([sheetBelowAppBar]) unless
/// [constraints] say otherwise.
///
/// `docs/DESIGN_DIRECTION.md` keeps "bottom-sheet interaction for secondary
/// actions" as a KEEP-worthy pattern from the reference app
/// (`docs/reference/18_VISUAL_REFERENCE_NOTES.md` §4) — this is Tahfeez's
/// own implementation of that pattern, used for verse options, filters,
/// and any other secondary/contextual action sheet.
///
/// [besideOnWide]: on a wide landscape screen (a tablet's, a desktop
/// window), a panel at the screen's end side instead, the page left in
/// view beside it — for what is read with the page (a session's results,
/// a word's mistakes).
Future<T?> showTahfeezModalBottomSheet<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  bool besideOnWide = false,
}) {
  if (besideOnWide && sheetBesidePage(context)) {
    return _showSidePanel<T>(context: context, title: title, builder: builder);
  }
  // (Counted open by [TahfeezPopupObserver].)
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Over the whole app (a shell's bottom bar included), not inside the
    // tab's own navigator, where that bar would cover its bottom.
    useRootNavigator: true,
    constraints: constraints ?? sheetBelowAppBar(context),
    // Lifted above the keyboard while a field in it is being typed into.
    builder: (context) => GlassSheet(
      child: AnimatedPadding(
        duration: TahfeezMotionDuration.fast,
        curve: TahfeezMotionCurves.standard,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
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
                    padding: const EdgeInsetsDirectional.only(
                      bottom: TahfeezSpacing.sm,
                      start: TahfeezSpacing.md,
                      end: TahfeezSpacing.xs,
                    ),
                    // Every titled sheet closes the same way: an ✕ at the
                    // header's far end (right; left in RTL).
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        SheetCloseButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Whether a sheet shown now may sit beside the page: a landscape screen
/// wide enough for the page and a panel side by side.
bool sheetBesidePage(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= sidePanelFrom && size.width > size.height;
}

/// A window's width from which sheets may open beside the page.
const sidePanelFrom = 960.0;

/// A panel's width beside the page.
double sidePanelWidth(BuildContext context) =>
    math.min(440, MediaQuery.sizeOf(context).width * 0.4);

/// The sheet as a panel at the screen's end side (right; left in RTL), as
/// tall as the screen, sliding in — the rest of the screen in view, a tap
/// there closes it.
Future<T?> _showSidePanel<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
}) {
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black12,
    transitionDuration: TahfeezMotionDuration.medium,
    pageBuilder: (context, _, _) {
      final theme = Theme.of(context);
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          key: const ValueKey('sheet-side-panel'),
          width: sidePanelWidth(context),
          height: double.infinity,
          child: Material(
            color:
                theme.bottomSheetTheme.modalBackgroundColor ??
                theme.colorScheme.surfaceContainerLow,
            elevation: 3,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: TahfeezSpacing.sm,
                        bottom: TahfeezSpacing.sm,
                        start: TahfeezSpacing.md,
                        end: TahfeezSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          SheetCloseButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: TahfeezSpacing.md),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: builder(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: Offset(rtl ? -1 : 1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// A sheet's ✕, at the far end of its header row: 48 × 48 to tap.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('sheet-close'),
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    icon: const Icon(Icons.close_rounded),
    onPressed: onPressed,
  );
}

/// A sheet's content as frosted glass: the screen behind it blurred under
/// the sheet's see-through paper (`bottomSheetTheme`), clipped to its
/// rounded top. (In a browser: plain, opaque paper.)
///
/// [handle]: a drag handle on the glass, as the sheet's own would be
/// (`showDragHandle`, which sits above its content: a strip of unblurred
/// page there, and the glass's rounded corners showing under it).
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.handle = false,
    this.closable = false,
  });

  final Widget child;
  final bool handle;

  /// With [handle]: an ✕ in the handle's band, at its far end (right; left
  /// in RTL) — on the handle's line, no row of its own.
  final bool closable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = !handle
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Material's drag handle: 32 × 4 in a 48-high band.
              SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              theme.bottomSheetTheme.dragHandleColor ??
                              theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (closable)
                      PositionedDirectional(
                        top: 0,
                        end: TahfeezSpacing.xs,
                        child: SheetCloseButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(child: child),
            ],
          );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(TahfeezRadii.lg),
      ),
      // In a browser, no blur: the Mushaf's pages there are the browser's
      // own canvases, which it cannot blur — only the dim over them, its
      // edges darkened. The sheet is opaque there instead (`app_theme`).
      child: kIsWeb
          ? content
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: content,
            ),
    );
  }
}
