import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/localization/supported_locales.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/components/tahfeez_card.dart';
import '../core/theme/tahfeez_theme_families.dart';
import '../core/theme/theme_controller.dart';

/// Proves the app's foundations work together end to end: Tahfeez
/// light/dark/family/dynamic-color theming, RTL layout, and responsive
/// breakpoints. Originally Milestone 1's only screen; Milestone 3 extends it
/// with theme-family and dynamic-color controls now that both exist, and
/// links to the full component gallery.
class FoundationDemoScreen extends ConsumerWidget {
  const FoundationDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = TahfeezBreakpoint.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foundationDemoTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.lg,
            children: [
              Text(
                l10n.foundationDemoBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              _ThemeModeCard(l10n: l10n),
              const _ThemeFamilyCard(),
              const _DynamicColorCard(),
              _LanguageCard(l10n: l10n),
              _BreakpointCard(l10n: l10n, breakpoint: breakpoint),
              FilledButton.tonal(
                onPressed: () => context.go('/debug/gallery'),
                child: const Text('Open component gallery'),
              ),
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

    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
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
    );
  }
}

class _ThemeFamilyCard extends ConsumerWidget {
  const _ThemeFamilyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(themeFamilyControllerProvider);

    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          Text('Color family', style: Theme.of(context).textTheme.titleMedium),
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
        ],
      ),
    );
  }
}

class _DynamicColorCard extends ConsumerWidget {
  const _DynamicColorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useDynamicColor = ref.watch(dynamicColorPreferenceControllerProvider);

    return TahfeezCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use system dynamic color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Overrides the color family above where the platform provides one (Android 12+).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: useDynamicColor,
            onChanged: (value) => ref
                .read(dynamicColorPreferenceControllerProvider.notifier)
                .setEnabled(value),
          ),
        ],
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

    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          Text(
            l10n.languageLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: TahfeezSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('System'),
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

class _BreakpointCard extends StatelessWidget {
  const _BreakpointCard({required this.l10n, required this.breakpoint});

  final AppLocalizations l10n;
  final TahfeezBreakpoint breakpoint;

  String _label(TahfeezBreakpoint breakpoint) => switch (breakpoint) {
    TahfeezBreakpoint.phone => l10n.breakpointPhone,
    TahfeezBreakpoint.tablet => l10n.breakpointTablet,
    TahfeezBreakpoint.desktop => l10n.breakpointDesktop,
  };

  @override
  Widget build(BuildContext context) {
    // The column count itself changes structurally per breakpoint, rather
    // than just labelling the breakpoint, to prove the layout genuinely
    // adapts (per docs/DESIGN_DIRECTION.md's phone/tablet/desktop guidance).
    final columns = switch (breakpoint) {
      TahfeezBreakpoint.phone => 1,
      TahfeezBreakpoint.tablet => 2,
      TahfeezBreakpoint.desktop => 3,
    };

    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          Text(
            l10n.breakpointDescription(_label(breakpoint)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: TahfeezSpacing.sm,
            crossAxisSpacing: TahfeezSpacing.sm,
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
    );
  }
}
