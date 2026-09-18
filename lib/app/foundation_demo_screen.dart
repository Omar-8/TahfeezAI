import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/localization/supported_locales.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/theme_controller.dart';

/// Proves the Milestone 1 foundations work together: Tahfeez light/dark
/// theming, RTL layout, and responsive breakpoints.
///
/// This is deliberately the *only* screen this milestone ships — real
/// feature screens (Home, Reader, Search, ...) are out of scope here per
/// `prompts/milestones/MILESTONE_01_FLUTTER_FOUNDATION.md`, which asks for
/// "only enough UI to prove" these foundations.
class FoundationDemoScreen extends ConsumerWidget {
  const FoundationDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = AppBreakpoint.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foundationDemoTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: [
              Text(
                l10n.foundationDemoBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              _ThemeModeCard(l10n: l10n),
              _LanguageCard(l10n: l10n),
              _BreakpointCard(l10n: l10n, breakpoint: breakpoint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(
              l10n.themeModeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeModeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeModeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeModeDark),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeModeControllerProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(
              l10n.languageLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('System'),
                  selected: locale == null,
                  onSelected: (_) => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(null),
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
      ),
    );
  }
}

class _BreakpointCard extends StatelessWidget {
  const _BreakpointCard({required this.l10n, required this.breakpoint});

  final AppLocalizations l10n;
  final AppBreakpoint breakpoint;

  String _label(AppBreakpoint breakpoint) => switch (breakpoint) {
    AppBreakpoint.phone => l10n.breakpointPhone,
    AppBreakpoint.tablet => l10n.breakpointTablet,
    AppBreakpoint.desktop => l10n.breakpointDesktop,
  };

  @override
  Widget build(BuildContext context) {
    // The column count itself changes structurally per breakpoint, rather
    // than just labelling the breakpoint, to prove the layout genuinely
    // adapts (per docs/DESIGN_DIRECTION.md's phone/tablet/desktop guidance).
    final columns = switch (breakpoint) {
      AppBreakpoint.phone => 1,
      AppBreakpoint.tablet => 2,
      AppBreakpoint.desktop => 3,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(
              l10n.breakpointDescription(_label(breakpoint)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 3,
              children: List.generate(
                columns,
                (i) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
