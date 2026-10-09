import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
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
            _HomeBrandHeader(l10n: l10n),
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

/// The app's icon and name at the top of Home.
class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        spacing: TahfeezSpacing.smPlus,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/branding/app_icon_192.png',
              width: 44,
              height: 44,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Text(
            l10n.appName,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
