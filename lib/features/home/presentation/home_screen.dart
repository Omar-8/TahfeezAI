import 'package:flutter/material.dart';

import '../../../core/ui/bar_space.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_sky.dart';
import 'home_store_prompts.dart';

import '../../../core/ui/back_to_exit.dart';
import '../../../core/ui/first_run.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import 'sections/home_daily_ayah_section.dart';
import 'sections/home_featured_reading_section.dart';
import 'sections/home_memorization_section.dart';
import 'sections/home_read_history_section.dart';
import 'sections/home_resource_updates_banner.dart';
import '../../../core/ui/app_name_text.dart';

/// Tahfeez's Home screen — the app's single non-tabbed landing screen
/// (`docs/reference/03_NAVIGATION_MAP.md`), composed from the
/// reference-equivalent information hierarchy this milestone requires:
/// resource/update notices, Daily Ayah, Continue Reading, today's
/// memorization, and Featured Reading. The persistent
/// mini-player region (item 6) is mounted at the app-shell level
/// (`lib/app/shell/app_shell.dart`), not here, so it can persist across
/// Home/Quran/Search rather than being tied to one screen.
///
/// A [SingleChildScrollView] over a plain [Column], not a lazy [ListView],
/// on purpose: the section count is small and fixed, and this guarantees
/// every section exists in the widget tree for widget tests without needing
/// to scroll first (the same lesson recorded for `ComponentGalleryScreen`
/// in `docs/ARCHITECTURE.md` §11a).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Back on Home: once to be told, twice (within 2 s) to leave the app.
    // The sky of the time of day behind the top (under the status bar too),
    // the cards frosted glass over it.
    return BackToExit(
      child: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: HomeSky()),
          TahfeezGlass(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: withBarSpace(
                  context,
                  const EdgeInsets.all(TahfeezSpacing.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeBrandHeader(l10n: l10n),
                    // The first time Home shows: a word of welcome (a dialog; no
                    // room of its own).
                    const _WelcomeOnce(),
                    const SizedBox(height: TahfeezSpacing.md),
                    // Only when there are updates, with its own space below.
                    const HomeResourceUpdatesBanner(),
                    // (Spaced apart here, not above: hidden parts left a gap each,
                    // three between the header and the daily ayah.)
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: TahfeezSpacing.lg,
                      children: [
                        HomeDailyAyahSection(),
                        HomeReadHistorySection(),
                        HomeMemorizationSection(),
                        HomeFeaturedReadingSection(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's name, and below it the salam on one line.
class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNameText(
            l10n.appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          // Update offers and, now and then, a rating request (draws
          // nothing).
          const HomeStorePrompts(),
          // Shrinks rather than wraps on narrow screens or large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.homeSalam,
              maxLines: 1,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing on screen: the first time Home shows, a welcome — what the app
/// is for, and that its recitation checking is still learning.
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
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('home-welcome'),
          title: Text(l10n.homeWelcomeTitle),
          content: SingleChildScrollView(child: Text(l10n.homeWelcomeBody)),
          actions: [
            FilledButton(
              key: const ValueKey('home-welcome-continue'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.homeWelcomeContinue),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
