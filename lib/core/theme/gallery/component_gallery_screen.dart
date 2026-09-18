import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/locale_controller.dart';
import '../../localization/supported_locales.dart';
import '../app_spacing.dart';
import '../components/components.dart';
import '../tahfeez_theme_families.dart';
import '../theme_controller.dart';
import 'memorization_state_gallery.dart';

/// Internal, dev-only gallery of every Tahfeez design-system component, in
/// every theme family, both brightnesses, and both a supported LTR (English)
/// and RTL (Arabic) locale — this milestone's explicit "component gallery"
/// deliverable.
///
/// Not linked from any user-facing navigation; reached only via the
/// `/gallery` route from the foundation demo screen, or directly by URL on
/// web. Exists purely so future milestones (and this one's own review) have
/// one place to see every token-driven component at once, in every theme
/// combination, without needing a real screen built around each one yet.
class ComponentGalleryScreen extends ConsumerWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final family = ref.watch(themeFamilyControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: const TahfeezAppBar(title: Text('Component gallery')),
      // A plain scroll view over a Column, not a lazy ListView: this screen
      // is a bounded, dev-only tool (never a long/unbounded feed), so every
      // section should exist in the tree immediately -- both so a reviewer
      // scrolling fast never sees a blank frame and so widget tests can find
      // and tap any section without first scrolling it into the viewport.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GalleryControls(
              themeMode: themeMode,
              family: family,
              locale: locale,
            ),
            const SizedBox(height: TahfeezSpacing.lg),
            const TahfeezSectionHeader(title: 'Cards', icon: Icons.crop_square),
            const SizedBox(height: TahfeezSpacing.sm),
            const TahfeezCard(child: Text('A plain TahfeezCard.')),
            const SizedBox(height: TahfeezSpacing.sm),
            TahfeezCard(
              onTap: () {},
              child: const Text('A tappable TahfeezCard.'),
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Quran section cards',
              icon: Icons.menu_book_outlined,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            TahfeezQuranSectionCard(
              number: 1,
              title: 'Chapter one',
              subtitle: '7 verses',
              onTap: () {},
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            TahfeezQuranSectionCard(
              number: 2,
              title: 'Juz two',
              subtitle: 'Spans two chapters',
              accentColor: Theme.of(context).colorScheme.tertiary,
              onTap: () {},
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'List rows & settings tiles',
              icon: Icons.list_alt,
            ),
            TahfeezCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TahfeezListRow(
                    title: 'A list row',
                    subtitle: 'With a subtitle',
                    leading: const Icon(Icons.bookmark_outline),
                  ),
                  const Divider(height: 1),
                  TahfeezSettingsTile(
                    title: 'Navigable setting',
                    subtitle: 'Tap to open something',
                    icon: Icons.language,
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  TahfeezSettingsTile.switchTile(
                    title: 'Toggle setting',
                    subtitle: 'Flips inline',
                    icon: Icons.dark_mode_outlined,
                    switchValue: true,
                    onSwitchChanged: (_) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Chips & segmented control',
              icon: Icons.tune,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            Wrap(
              spacing: TahfeezSpacing.sm,
              children: [
                TahfeezActionChip(
                  label: 'Manage',
                  icon: Icons.settings,
                  onPressed: () {},
                ),
                _StatefulFilterChipDemo(),
              ],
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            _StatefulSegmentedDemo(),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Resource rows & download progress',
              icon: Icons.download_outlined,
            ),
            const TahfeezCard(
              child: Column(
                children: [
                  TahfeezResourceRow(
                    title: 'Not yet downloaded',
                    state: TahfeezResourceRowState.notDownloaded,
                  ),
                  Divider(height: 1),
                  TahfeezResourceRow(
                    title: 'Downloading…',
                    state: TahfeezResourceRowState.downloading,
                    progressFraction: 0.62,
                  ),
                  Divider(height: 1),
                  TahfeezResourceRow(
                    title: 'Already downloaded',
                    state: TahfeezResourceRowState.downloaded,
                  ),
                  Divider(height: 1),
                  TahfeezResourceRow(
                    title: 'Update available',
                    state: TahfeezResourceRowState.outdated,
                  ),
                  Divider(height: 1),
                  TahfeezResourceRow(
                    title: 'Download failed',
                    state: TahfeezResourceRowState.failed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Verse action bar',
              icon: Icons.menu,
            ),
            TahfeezCard(
              child: TahfeezVerseActionBar(
                actions: [
                  TahfeezVerseAction(
                    icon: Icons.more_horiz,
                    tooltip: 'Options',
                    onPressed: () {},
                  ),
                  TahfeezVerseAction(
                    icon: Icons.play_circle_outline,
                    tooltip: 'Play',
                    onPressed: () {},
                  ),
                  TahfeezVerseAction(
                    icon: Icons.menu_book_outlined,
                    tooltip: 'Tafsir',
                    onPressed: () {},
                  ),
                  TahfeezVerseAction(
                    icon: Icons.bookmark,
                    tooltip: 'Bookmarked',
                    onPressed: () {},
                    isActive: true,
                  ),
                ],
                trailing: const Text('2:255'),
              ),
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Mini player shell',
              icon: Icons.play_circle_outline,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            _StatefulMiniPlayerDemo(),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Sheets & dialogs',
              icon: Icons.vertical_align_bottom,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            Wrap(
              spacing: TahfeezSpacing.sm,
              children: [
                FilledButton.tonal(
                  onPressed: () => showTahfeezModalBottomSheet(
                    context: context,
                    title: 'A Tahfeez bottom sheet',
                    builder: (context) => const Padding(
                      padding: EdgeInsets.all(TahfeezSpacing.md),
                      child: Text('Sheet content goes here.'),
                    ),
                  ),
                  child: const Text('Show bottom sheet'),
                ),
                FilledButton.tonal(
                  onPressed: () => showTahfeezConfirmationDialog(
                    context: context,
                    title: 'Delete bookmark?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  ),
                  child: const Text('Show destructive dialog'),
                ),
              ],
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Loading / empty / error states',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            const TahfeezCard(child: TahfeezLoadingView(message: 'Loading…')),
            const SizedBox(height: TahfeezSpacing.sm),
            const TahfeezCard(
              child: TahfeezEmptyView(message: 'Nothing here yet.'),
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            TahfeezCard(
              child: TahfeezErrorView(
                message: 'Something went wrong.',
                onRetry: () {},
              ),
            ),
            const SizedBox(height: TahfeezSpacing.lg),

            const TahfeezSectionHeader(
              title: 'Memorization-state placeholders',
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            const MemorizationStateGallery(),
            const SizedBox(height: TahfeezSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _GalleryControls extends ConsumerWidget {
  const _GalleryControls({
    required this.themeMode,
    required this.family,
    required this.locale,
  });

  final ThemeMode themeMode;
  final TahfeezThemeFamily family;
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          Text(
            'Gallery controls',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              for (final mode in ThemeMode.values)
                ChoiceChip(
                  label: Text(mode.name),
                  selected: themeMode == mode,
                  onSelected: (_) => ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode),
                ),
            ],
          ),
          Wrap(
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              for (final option in TahfeezThemeFamily.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: option.seedColor,
                    radius: 8,
                  ),
                  label: Text(option.displayName),
                  selected: family == option,
                  onSelected: (_) => ref
                      .read(themeFamilyControllerProvider.notifier)
                      .setFamily(option),
                ),
            ],
          ),
          Wrap(
            spacing: TahfeezSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('System locale'),
                selected: locale == null,
                onSelected: (_) =>
                    ref.read(localeControllerProvider.notifier).setLocale(null),
              ),
              for (final supported in kTahfeezSupportedLocales)
                ChoiceChip(
                  label: Text(supported.languageCode.toUpperCase()),
                  selected: locale == supported,
                  onSelected: (_) => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(supported),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatefulFilterChipDemo extends StatefulWidget {
  @override
  State<_StatefulFilterChipDemo> createState() =>
      _StatefulFilterChipDemoState();
}

class _StatefulFilterChipDemoState extends State<_StatefulFilterChipDemo> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return TahfeezFilterChip(
      label: 'Meccan',
      selected: _selected,
      onSelected: (v) => setState(() => _selected = v),
    );
  }
}

class _StatefulSegmentedDemo extends StatefulWidget {
  @override
  State<_StatefulSegmentedDemo> createState() => _StatefulSegmentedDemoState();
}

class _StatefulSegmentedDemoState extends State<_StatefulSegmentedDemo> {
  String _selected = 'verse';

  @override
  Widget build(BuildContext context) {
    return TahfeezSegmentedControl<String>(
      options: const {
        'verse': 'Verse-by-verse',
        'mushaf': 'Mushaf',
        'translation': 'Translation',
      },
      selected: _selected,
      onChanged: (v) => setState(() => _selected = v),
    );
  }
}

class _StatefulMiniPlayerDemo extends StatefulWidget {
  @override
  State<_StatefulMiniPlayerDemo> createState() =>
      _StatefulMiniPlayerDemoState();
}

class _StatefulMiniPlayerDemoState extends State<_StatefulMiniPlayerDemo> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return TahfeezMiniPlayerShell(
      title: 'Sample chapter',
      subtitle: 'Sample reciter',
      isPlaying: _isPlaying,
      progress: 0.4,
      onPlayPause: () => setState(() => _isPlaying = !_isPlaying),
    );
  }
}
