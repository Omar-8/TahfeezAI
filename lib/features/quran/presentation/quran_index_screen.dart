import '../../../app/shell/app_menu.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/presentation/home_sky.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
import 'go_to_ayah_sheet.dart';
import 'tabs/hizb_index_tab.dart';
import 'tabs/juz_index_tab.dart';
import 'tabs/topics_index_tab.dart';
import 'tabs/surah_index_tab.dart';
import '../../../core/ui/back_to_exit.dart';

/// Tahfeez's Quran index: a Tahfeez-owned tabbed browse surface (Surah /
/// Juz / Hizb / Topics) plus a "Go to" quick action (an ayah or a page), covering every
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
            // ☰ where Home has it (owner, 2026-11-20): 16 from the edge.
            leading: const Padding(
              padding: EdgeInsetsDirectional.only(start: TahfeezSpacing.md),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppMenuButton(),
              ),
            ),
            leadingWidth: 64,
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
                key: const ValueKey('quran-go-to'),
                icon: const Icon(Icons.pin_outlined),
                tooltip: AppLocalizations.of(context).quranGoTo,
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
              _FittingTabBar(
                controller: _tabController,
                labels: [
                  AppLocalizations.of(context).quranTabSurah,
                  AppLocalizations.of(context).quranTabJuz,
                  AppLocalizations.of(context).quranTabHizb,
                  AppLocalizations.of(context).quranTabTopics,
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SurahIndexTab(onSelect: _select),
                    JuzIndexTab(onSelect: _select),
                    HizbIndexTab(onSelect: _select),
                    TopicsIndexTab(onSelect: _select),
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

/// The tabs sharing the width when their labels fit; else scrolling
/// sideways, each label whole (a long one — «المواضيع» at large text).
class _FittingTabBar extends StatelessWidget {
  const _FittingTabBar({required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each tab its share of the width; its label and padding (16 each
        // side) to fit in it.
        final share = constraints.maxWidth / labels.length;
        final fits = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width + 32 <= share;
        });
        return TabBar(
          key: const ValueKey('quran-tabs'),
          controller: controller,
          isScrollable: !fits,
          tabAlignment: fits ? null : TabAlignment.start,
          tabs: [for (final label in labels) Tab(text: label)],
        );
      },
    );
  }
}
