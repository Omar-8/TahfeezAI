import 'package:flutter/material.dart';

import 'home_store_prompts.dart';

import '../../../core/ui/back_to_exit.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import 'sections/home_daily_ayah_section.dart';
import 'sections/home_featured_reading_section.dart';
import 'sections/home_memorization_section.dart';
import 'sections/home_read_history_section.dart';
import 'sections/home_resource_updates_banner.dart';

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
    return BackToExit(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.lg,
            children: [
              _HomeBrandHeader(l10n: l10n),
              const HomeResourceUpdatesBanner(),
              const HomeDailyAyahSection(),
              const HomeReadHistorySection(),
              const HomeMemorizationSection(),
              const HomeFeaturedReadingSection(),
            ],
          ),
        ),
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
          Text(
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
