import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/quran_location_routing.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui/app_name_text.dart';
import '../core/ui/display_hinge.dart';
import '../features/mushaf/application/reader_mode.dart';

/// A dual-screen device spanned (Surface Duo and the like; owner,
/// 2026-11-23): nothing under the hinge. The app keeps to one screen —
/// laid out as on a phone of that size, its sheets and dialogs too — and
/// the other shows Tahfeez's emblem and name; the Mushaf's pages, though, take both,
/// a page on each (`MushafPager` leaves the hinge as the spine).
///
/// Without a hinge (phones, tablets, foldables, browsers) it adds nothing.
class DualScreenLayer extends ConsumerStatefulWidget {
  const DualScreenLayer({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DualScreenLayer> createState() => _DualScreenLayerState();
}

class _DualScreenLayerState extends ConsumerState<DualScreenLayer> {
  String _path = '';

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_routed);
    _path = _current();
  }

  @override
  void didUpdateWidget(DualScreenLayer old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_routed);
      widget.router.routerDelegate.addListener(_routed);
      _path = _current();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_routed);
    super.dispose();
  }

  String _current() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  // The router tells of a new route while building: taken after the frame.
  void _routed() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final path = _current();
    if (path != _path && mounted) setState(() => _path = path);
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final hinge = DisplayHinge.of(media);
    // The child stays the first in the same tree either way, so the app
    // keeps its state as it moves between one screen and both.
    if (hinge == null) return _Split(app: null, child: widget.child);
    final pages =
        ref.watch(readerModeProvider) == ReaderMode.mushaf ||
        ref.watch(ayahViewPreferencesProvider.select((v) => v.layout)) !=
            AyahLayout.continuous;
    if (hinge.vertical && isQuranLocationPath(_path) && pages) {
      return _Split(app: null, child: widget.child);
    }
    // Side by side: the screen reading starts on (the right in Arabic);
    // one above the other: the top one.
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final first = !hinge.vertical || !rtl;
    return _Split(
      app: hinge.screen(first: first),
      other: hinge.screen(first: !first),
      child: widget.child,
    );
  }
}

/// [child] in [app] (the whole window when `null`), told that's its
/// screen; the emblem and name on [other].
class _Split extends StatelessWidget {
  const _Split({required this.app, this.other, required this.child});

  final Rect? app, other;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final app = this.app ?? Offset.zero & media.size;
    final w = media.size;
    EdgeInsets inside(EdgeInsets e) => EdgeInsets.fromLTRB(
      app.left <= 0 ? e.left : 0,
      app.top <= 0 ? e.top : 0,
      app.right >= w.width ? e.right : 0,
      app.bottom >= w.height ? e.bottom : 0,
    );
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: app,
          // Always the same widgets round the app (only the data
          // changes), so it keeps its state across one screen and both.
          child: MediaQuery(
            data: this.app == null
                ? media
                : media.copyWith(
                    size: app.size,
                    padding: inside(media.padding),
                    viewPadding: inside(media.viewPadding),
                    viewInsets: inside(media.viewInsets),
                    displayFeatures: const [],
                  ),
            child: child,
          ),
        ),
        if (other case final o?)
          Positioned.fromRect(
            rect: o,
            child: ColoredBox(
              key: const ValueKey('dual-screen-other'),
              color: scheme.surface,
              child: Center(
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TahfeezSpacing.md,
                    children: [
                      Image.asset(
                        'assets/branding/splash_emblem.png',
                        width: 120,
                        height: 120,
                      ),
                      AppNameText(
                        AppLocalizations.of(context).appName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
