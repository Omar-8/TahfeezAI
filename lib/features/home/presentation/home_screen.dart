import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import 'home_greeting.dart';
import 'sections/home_daily_ayah_section.dart';
import 'sections/home_featured_reading_section.dart';
import 'sections/home_memorization_teaser_section.dart';
import 'sections/home_read_history_section.dart';
import 'sections/home_resource_updates_banner.dart';

/// Tahfeez's Home screen — the app's single non-tabbed landing screen
/// (`docs/reference/03_NAVIGATION_MAP.md`), composed from the
/// reference-equivalent information hierarchy this milestone requires:
/// resource/update notices, Daily Ayah, Continue Reading, a reserved
/// Memorization slot, and Featured Reading. The persistent
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

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.lg,
          children: [
            _HomeGreetingHeader(l10n: l10n),
            const HomeResourceUpdatesBanner(),
            const HomeDailyAyahSection(),
            const HomeReadHistorySection(),
            const HomeMemorizationTeaserSection(),
            const HomeFeaturedReadingSection(),
          ],
        ),
      ),
    );
  }
}

class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final band = homeGreetingBandForHour(DateTime.now().hour);
    final greeting = switch (band) {
      HomeGreetingBand.morning => l10n.homeGreetingMorning,
      HomeGreetingBand.afternoon => l10n.homeGreetingAfternoon,
      HomeGreetingBand.evening => l10n.homeGreetingEvening,
    };

    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.xs,
        children: [
          Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            l10n.homeGreetingSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
