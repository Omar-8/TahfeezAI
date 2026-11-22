import '../../khatmah/presentation/khatmah_section.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core_providers.dart';
import '../../../core/ui/type_once.dart';

import '../../../core/ui/bar_space.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayer/presentation/prayer_card.dart';
import 'home_date_card.dart';
import 'home_sky.dart';
import 'home_store_prompts.dart';

import '../../../core/ui/back_to_exit.dart';
import '../../../core/ui/first_run.dart';
import '../../onboarding/presentation/first_run_setup.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../../core/theme/components/components.dart';
import 'sections/home_daily_ayah_section.dart';
import 'sections/home_featured_reading_section.dart';
import 'sections/home_memorization_section.dart';
import 'sections/home_read_history_section.dart';
import 'sections/home_resource_updates_banner.dart';
import '../../../core/ui/app_name_text.dart';

import 'package:go_router/go_router.dart';

import '../../../app/shell/app_menu.dart';
import '../../../core/routing/app_routes.dart';

/// Tahfeez's Home screen — the app's single non-tabbed landing screen
/// (`docs/reference/03_NAVIGATION_MAP.md`), composed from the
/// reference-equivalent information hierarchy this milestone requires:
/// resource/update notices, Continue Reading, today's memorization, Daily
/// Ayah, and (in a browser) Featured Reading. The persistent
/// mini-player region (item 6) is mounted at the app-shell level
/// (`lib/app/shell/app_shell.dart`), not here, so it can persist across
/// Home/Quran/Search rather than being tied to one screen.
///
/// A [SingleChildScrollView] over a plain [Column], not a lazy [ListView],
/// on purpose: the section count is small and fixed, and this guarantees
/// every section exists in the widget tree for widget tests without needing
/// to scroll first (the same lesson recorded for `ComponentGalleryScreen`
/// in `docs/ARCHITECTURE.md` §11a).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final web = ref.watch(platformCapabilitiesProvider).isWeb;

    // Back on Home: once to be told, twice (within 2 s) to leave the app.
    // The sky of the time of day behind the top (under the status bar too),
    // the cards frosted glass over it. The shell gives Home the whole width
    // (app_shell.dart): the sky spans it, and the cards keep a reading
    // column — or, wide enough (a large tablet), two side by side.
    // On a tablet the cards sit in the middle of the height (a phone fills
    // it anyway), the sky reaching down behind them.
    final centered = !TahfeezBreakpoint.of(context).isPhone;
    // Its top as the other tabs' bars (56 high, ☰ in the middle): the menu
    // button in the same place on all three (owner, 2026-11-20).
    final padding = withBarSpace(
      context,
      const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        (kToolbarHeight - AppMenuButton.size) / 2,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
    );
    return BackToExit(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: centered
                ? HomeSky(height: MediaQuery.sizeOf(context).height * 0.8)
                : const HomeSky(),
          ),
          TahfeezGlass(
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= homeTwoColumnWidth;
                  return SingleChildScrollView(
                    padding: padding,
                    child: ConstrainedBox(
                      // At least the screen's height: room to centre in.
                      constraints: BoxConstraints(
                        minHeight: centered
                            ? math.max(
                                0,
                                constraints.maxHeight - padding.vertical,
                              )
                            : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: twoColumns
                                ? homeWideMaxWidth
                                : TahfeezContentWidth.maxReading,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HomeBrandHeader(l10n: l10n),
                              const SizedBox(height: TahfeezSpacing.md),
                              // Today: its date, time and Hijri date,
                              // an event coming (owner, 2026-11-21).
                              const HomeDateCard(),
                              // Today's prayer times, under the date
                              // (owner, 2026-11-21).
                              const SizedBox(height: TahfeezSpacing.sm),
                              const PrayerTimesCard(),
                              const SizedBox(height: TahfeezSpacing.sm),
                              // Shortcuts (owner, 2026-11-20): the Qibla
                              // first, more to come.
                              const _HomeShortcuts(),
                              // The first time Home shows: a word of welcome (a
                              // dialog; no room of its own).
                              const _WelcomeOnce(),
                              const SizedBox(height: TahfeezSpacing.md),
                              // Only when there are updates, with its own space
                              // below.
                              const HomeResourceUpdatesBanner(),
                              // (Spaced apart here, not above: hidden parts left
                              // a gap each, three between the header and the
                              // daily ayah.)
                              // Where to carry on first — reading, then
                              // today's memorization — then the daily ayah
                              // (owner, 2026-11-07), the khatmah before it;
                              // Featured Reading in a
                              // browser only.
                              if (twoColumns)
                                Row(
                                  key: const ValueKey('home-two-columns'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: TahfeezSpacing.lg,
                                  children: [
                                    const Expanded(
                                      child: _Sections([
                                        HomeReadHistorySection(),
                                        HomeKhatmahSection(),
                                        HomeDailyAyahSection(),
                                      ]),
                                    ),
                                    Expanded(
                                      child: _Sections([
                                        const HomeMemorizationSection(),
                                        if (web)
                                          const HomeFeaturedReadingSection(),
                                      ]),
                                    ),
                                  ],
                                )
                              else
                                _Sections([
                                  const HomeReadHistorySection(),
                                  const HomeMemorizationSection(),
                                  const HomeKhatmahSection(),
                                  const HomeDailyAyahSection(),
                                  if (web) const HomeFeaturedReadingSection(),
                                ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// From this width Home's sections sit in two columns (a 13" iPad upright,
/// a desktop window); below it, one reading column as on a phone.
@visibleForTesting
const homeTwoColumnWidth = 900.0;

/// The two columns' width at most, together.
@visibleForTesting
const homeWideMaxWidth = 1200.0;

/// Home's sections, one below the other.
class _Sections extends StatelessWidget {
  const _Sections(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TahfeezSpacing.lg,
    children: children,
  );
}

/// The app's name, and below it the salam on one line.
class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ☰ (the side menu) before the name; the salam below them, the whole
    // width its own (owner, 2026-11-20: beside the buttons it shrank).
    return _brand(theme);
  }

  Widget _brand(ThemeData theme) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // As tall as the button, whatever the text size or script: ☰
          // where the other tabs' bars have it (owner, 2026-11-20: at a
          // larger text size the taller name pushed it down); the name
          // shrinks to fit rather.
          SizedBox(
            height: AppMenuButton.size,
            child: Row(
              spacing: TahfeezSpacing.smPlus,
              children: [
                const AppMenuButton(),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AppNameText(
                      l10n.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TahfeezSpacing.xs),
          // Update offers and, now and then, a rating request (draws
          // nothing).
          const HomeStorePrompts(),
          // Shrinks rather than wraps on narrow screens or large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            // Revealed word by word as the app opens.
            child: TypeOnce(
              id: 'home-salam',
              length: l10n.homeSalam.length,
              delay: const Duration(milliseconds: 250),
              perCharacter: const Duration(milliseconds: 30),
              builder: (context, typed) => Text.rich(
                TextSpan(
                  children: revealedWordSpans(
                    l10n.homeSalam,
                    typed,
                    theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                maxLines: 1,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home's shortcuts, under its header: glass pills in a row (scrolling
/// sideways when they outgrow it).
class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const ValueKey('home-shortcuts'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        spacing: TahfeezSpacing.sm,
        children: [
          _Shortcut(
            key: const ValueKey('home-qibla'),
            icon: Icons.explore_outlined,
            label: l10n.menuQibla,
            tooltip: l10n.menuQiblaSub,
            onTap: () => context.push(AppRoutes.qibla),
          ),
          // Athkar beside it (owner, 2026-11-21).
          _Shortcut(
            key: const ValueKey('home-athkar'),
            icon: Icons.record_voice_over_outlined,
            label: l10n.athkarTitle,
            tooltip: l10n.athkarMenuSubtitle,
            onTap: () => context.push(AppRoutes.athkar),
          ),
          // Habits beside them (owner, 2026-11-21).
          _Shortcut(
            key: const ValueKey('home-habits'),
            icon: Icons.event_available_outlined,
            label: l10n.habitsTitle,
            tooltip: l10n.habitsMenuSubtitle,
            onTap: () => context.push(AppRoutes.habits),
          ),
        ],
      ),
    );
  }
}

/// One shortcut: the cards' glass as a pill, its icon and name in the
/// app's green; 48 high, a full tap target.
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label, tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: TahfeezGlassSurface(
        raised: true,
        // No live blur (as most of the app's glass): blurring what scrolled
        // beneath it made it flicker as Home scrolled (owner, 2026-11-21).
        blur: false,
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: TahfeezSpacing.sm,
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing on screen: the first time Home shows, the setup — a welcome
/// (what the app is for, and that its recitation checking is still
/// learning), the language, what to begin with, a reciter, a reminder.
/// (Those who saw the old welcome dialog are not asked again: the same
/// key.)
class _WelcomeOnce extends ConsumerStatefulWidget {
  const _WelcomeOnce();

  @override
  ConsumerState<_WelcomeOnce> createState() => _WelcomeOnceState();
}

class _WelcomeOnceState extends ConsumerState<_WelcomeOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !await firstRunDue(ref, 'welcome') || !mounted) return;
      await showFirstRunSetup(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
