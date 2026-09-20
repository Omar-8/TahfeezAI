import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
import 'go_to_ayah_sheet.dart';
import 'tabs/hizb_index_tab.dart';
import 'tabs/juz_index_tab.dart';
import 'tabs/page_index_tab.dart';
import 'tabs/surah_index_tab.dart';

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

    return Scaffold(
      appBar: TahfeezAppBar(
        title: const Text('Quran'),
        centerTitle: false,
        actions: [
          // Beside the page-jump ("Go to Ayah") button, not a full-width
          // chip row below the app bar taking real estate away from the
          // tab content -- only shown once there's somewhere to jump back
          // to.
          if (recent != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Jump back in',
              onPressed: () => goToQuranLocation(context, recent),
            ),
          IconButton(
            icon: const Icon(Icons.pin_outlined),
            tooltip: 'Go to Ayah',
            onPressed: _goToAyah,
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Surah'),
              Tab(text: 'Juz'),
              Tab(text: 'Hizb'),
              Tab(text: 'Page'),
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
    );
  }
}
