import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/presentation/home_sky.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';

import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
import 'go_to_ayah_sheet.dart';
import 'tabs/hizb_index_tab.dart';
import 'tabs/juz_index_tab.dart';
import 'tabs/page_index_tab.dart';
import 'tabs/surah_index_tab.dart';
import '../../../core/ui/back_to_exit.dart';

/// Tahfeez's Quran index: a Tahfeez-owned tabbed browse surface (Surah /
/// Juz / Hizb / Page) plus a "Go to Ayah" quick action, covering every
/// navigation mode this milestone requires. Every result — from any tab or
/// the quick action — resolves to a [QuranLocation] and routes through the
/// single [goToQuranLocation] helper (`core/routing`), never a
/// screen-specific route string.
class QuranIndexScreen extends ConsumerStatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  ConsumerState<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends ConsumerState<QuranIndexScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 4, vsync: this);

  void _select(QuranLocation location) {
    ref.read(recentQuranLocationControllerProvider.notifier).record(location);
    goToQuranLocation(context, location);
  }

  Future<void> _goToAyah() async {
    final location = await showGoToAyahSheet(context);
    if (location != null && mounted) {
      _select(location);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentQuranLocationControllerProvider);

    return BackToExit(
      child: SkyBackdrop(
        child: Scaffold(
          appBar: TahfeezAppBar(
            title: Text(AppLocalizations.of(context).quranTitle),
            centerTitle: false,
            actions: [
              // Beside the page-jump ("Go to Ayah") button, not a full-width
              // chip row below the app bar taking real estate away from the
              // tab content -- only shown once there's somewhere to jump back
              // to.
              if (recent != null)
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: AppLocalizations.of(context).quranJumpBack,
                  onPressed: () => goToQuranLocation(context, recent),
                ),
              IconButton(
                icon: const Icon(Icons.pin_outlined),
                tooltip: AppLocalizations.of(context).quranGoToAyah,
                onPressed: _goToAyah,
              ),
              IconButton(
                key: const ValueKey('quran-bookmarks'),
                icon: const Icon(Icons.bookmarks_outlined),
                tooltip: AppLocalizations.of(context).bookmarksTitle,
                onPressed: () => context.go(AppRoutes.bookmarks),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: AppLocalizations.of(context).navSearch,
                onPressed: () => context.go(AppRoutes.search),
              ),
            ],
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: AppLocalizations.of(context).quranTabSurah),
                  Tab(text: AppLocalizations.of(context).quranTabJuz),
                  Tab(text: AppLocalizations.of(context).quranTabHizb),
                  Tab(text: AppLocalizations.of(context).quranTabPage),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SurahIndexTab(onSelect: _select),
                    JuzIndexTab(onSelect: _select),
                    HizbIndexTab(onSelect: _select),
                    PageIndexTab(onSelect: _select),
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
