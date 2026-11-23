import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/tahfeez_motion.dart';
import '../../core/ui/app_name_text.dart';

/// The shell's [Scaffold] — the one whose side menu [AppMenuButton] opens,
/// from any of the three tabs (each has a Scaffold of its own inside it).
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

/// ☰ at the start of a tab's top bar: the side menu (Qibla, Bookmarks,
/// Settings, About — owner, 2026-11-20). Opened by the button only: an edge
/// swipe would fight Android's back gesture.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  /// Its diameter.
  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // A plain icon button (owner, 2026-11-20: not glass), 48 across, in
    // the primary colour.
    return IconButton(
      key: const ValueKey('app-menu'),
      tooltip: l10n.menuOpen,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(Icons.menu_rounded, size: 26, color: scheme.primary),
      onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
    );
  }
}

/// The side menu: frosted glass over the app (the sheets' glass), the app's
/// name at its head, then its places, each sliding in after the one before
/// as it opens. On the start side (right in Arabic and the other
/// right-to-left languages).
class AppMenuDrawer extends StatefulWidget {
  const AppMenuDrawer({super.key});

  @override
  State<AppMenuDrawer> createState() => _AppMenuDrawerState();
}

class _AppMenuDrawerState extends State<AppMenuDrawer>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: TahfeezMotionDuration.slow + TahfeezMotionDuration.medium,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.status != AnimationStatus.dismissed) return;
    // The phone's (or the app's) "remove animations": all there at once.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// [route] over the tab; [inTab]: first to that tab (Bookmarks, the
  /// Quran tab's), then over it — back returns to the tab either way.
  void _open(String route, {String? inTab}) {
    appShellScaffoldKey.currentState?.closeDrawer();
    final router = GoRouter.of(context);
    if (inTab != null) router.go(inTab);
    router.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final entries = [
      (
        key: 'qibla',
        icon: Icons.explore_outlined,
        title: l10n.menuQibla,
        subtitle: l10n.menuQiblaSub,
        onTap: () => _open(AppRoutes.qibla),
      ),
      (
        key: 'prayer',
        icon: Icons.mosque_outlined,
        title: l10n.prayerTitle,
        subtitle: l10n.prayerMenuSub,
        onTap: () => _open(AppRoutes.prayer),
      ),
      (
        key: 'athkar',
        icon: Icons.record_voice_over_outlined,
        title: l10n.athkarTitle,
        subtitle: l10n.athkarMenuSubtitle,
        onTap: () => _open(AppRoutes.athkar),
      ),
      (
        key: 'habits',
        icon: Icons.event_available_outlined,
        title: l10n.habitsTitle,
        subtitle: l10n.habitsMenuSubtitle,
        onTap: () => _open(AppRoutes.habits),
      ),
      // The Hijri calendar, as Home's date card opens it (owner, 2026-11-23).
      (
        key: 'calendar',
        icon: Icons.calendar_month_outlined,
        title: l10n.hijriCalendarTitle,
        subtitle: l10n.hijriCalendarMenuSub,
        onTap: () => _open(AppRoutes.hijriCalendar),
      ),
      (
        key: 'bookmarks',
        icon: Icons.bookmark_outline_rounded,
        title: l10n.bookmarksTitle,
        subtitle: null,
        onTap: () => _open(AppRoutes.bookmarks, inTab: AppRoutes.quran),
      ),
      (
        key: 'settings',
        icon: Icons.settings_outlined,
        title: l10n.settingsTitle,
        subtitle: null,
        onTap: () => _open(AppRoutes.settings),
      ),
      (
        key: 'about',
        icon: Icons.info_outline_rounded,
        title: l10n.aboutTitle,
        subtitle: l10n.aboutSubtitle,
        onTap: () => _open(AppRoutes.about),
      ),
    ];
    final end = Directionality.of(context) == TextDirection.ltr
        ? const BorderRadius.horizontal(right: Radius.circular(TahfeezRadii.lg))
        : const BorderRadius.horizontal(left: Radius.circular(TahfeezRadii.lg));

    // Each part's slide-and-fade, a little after the one before.
    Widget staggered(int index, Widget child) {
      final start = (index * 0.09).clamp(0.0, 0.6);
      final curve = CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          start,
          start + 0.4,
          curve: TahfeezMotionCurves.standard,
        ),
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: Offset(
              Directionality.of(context) == TextDirection.ltr ? -0.12 : 0.12,
              0,
            ),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    }

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: end,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: kIsWeb
              ? [scheme.surface, scheme.surface]
              : [
                  scheme.surface.withValues(alpha: dark ? 0.82 : 0.88),
                  scheme.surfaceContainerLow.withValues(
                    alpha: dark ? 0.78 : 0.84,
                  ),
                ],
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.8),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.smPlus,
            vertical: TahfeezSpacing.lg,
          ),
          children: [
            staggered(
              0,
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TahfeezSpacing.sm,
                  0,
                  TahfeezSpacing.sm,
                  TahfeezSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppNameText(
                      l10n.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TahfeezSpacing.xs),
                    Text(
                      l10n.homeSalam,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < entries.length; i++)
              staggered(
                i + 1,
                Padding(
                  padding: const EdgeInsets.only(bottom: TahfeezSpacing.xs),
                  child: _MenuEntry(
                    key: ValueKey('menu-${entries[i].key}'),
                    icon: entries[i].icon,
                    title: entries[i].title,
                    subtitle: entries[i].subtitle,
                    onTap: entries[i].onTap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Drawer(
      key: const ValueKey('app-menu-drawer'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: end),
      child: ClipRRect(
        borderRadius: end,
        // In a browser, no blur (the Mushaf's canvases there can't be
        // blurred): the panel opaque instead, as the sheets are.
        child: kIsWeb
            ? panel
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: panel,
              ),
      ),
    );
  }
}

/// One of the menu's places: its icon on a soft tonal tile, its name (and a
/// line about it), a press that ripples in the app's colours.
class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.sm,
            vertical: TahfeezSpacing.smPlus,
          ),
          child: Row(
            spacing: TahfeezSpacing.md,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(TahfeezRadii.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(TahfeezSpacing.sm),
                  child: Icon(icon, color: scheme.primary, size: 22),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle case final s?)
                      Text(
                        s,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
