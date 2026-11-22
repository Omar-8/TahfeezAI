import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/first_run.dart';

/// Settings → "Ṣalawāt on the Prophet ﷺ": as the app opens, a word
/// inviting the ṣalawāt (owner, 2026-11-20) — on unless turned off, here or
/// in the reminder itself.
class SalawatReminderController extends Notifier<bool> {
  static const storageKey = 'salawat.onStart';

  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getBool(storageKey);
    if (ref.mounted && stored != null) state = stored;
  }

  Future<void> setEnabled(bool on) async {
    state = on;
    await ref.read(browserStorageProvider).setBool(storageKey, on);
  }
}

final salawatReminderProvider =
    NotifierProvider<SalawatReminderController, bool>(
      SalawatReminderController.new,
    );

/// Nothing on screen: once each time the app opens, a moment after, the
/// ṣalawāt reminder — not on the first run (its setup comes first), not
/// over another prompt, not when turned off.
class SalawatOnStart extends ConsumerStatefulWidget {
  const SalawatOnStart({super.key});

  /// How long after the app opens.
  static const delay = Duration(milliseconds: 1500);

  /// Once per launch (the shell may be built again).
  static bool shownThisLaunch = false;

  @override
  ConsumerState<SalawatOnStart> createState() => _SalawatOnStartState();
}

class _SalawatOnStartState extends ConsumerState<SalawatOnStart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (SalawatOnStart.shownThisLaunch || !ref.read(firstRunPromptsProvider)) {
      return;
    }
    SalawatOnStart.shownThisLaunch = true;
    unawaited(_schedule());
  }

  Future<void> _schedule() async {
    final storage = ref.read(browserStorageProvider);
    // The first run's setup (its welcome not yet seen) comes first.
    final welcomed = await storage.getBool('firstRun.welcome') ?? false;
    final on =
        await storage.getBool(SalawatReminderController.storageKey) ?? true;
    if (!welcomed || !on || !mounted) return;
    _timer = Timer(SalawatOnStart.delay, () {
      if (!mounted) return;
      // Something else already showing (an update offer, a sheet): not
      // over it.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      unawaited(showSalawatReminder(context));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The reminder: the ṣalawāt in Arabic, the hadith on its reward, and
/// "Don't show this again" (turning it off, as Settings does).
Future<void> showSalawatReminder(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  var never = false;
  final off = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          key: const ValueKey('salawat-reminder'),
          // Scrolls at large text sizes and on small screens.
          scrollable: true,
          icon: Icon(Icons.favorite_outline_rounded, color: scheme.primary),
          title: Text(l10n.salawatTitle, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The ṣalawāt, in Arabic in every language.
              Text(
                'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
                key: const ValueKey('salawat-text'),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: TahfeezSpacing.md),
              // Its reward (Sahih Muslim 408), in Arabic, then its meaning.
              Text(
                '«مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرًا» '
                '— رواه مسلم',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              if (!arabic) ...[
                const SizedBox(height: TahfeezSpacing.xs),
                Text(
                  l10n.salawatHadith,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: TahfeezSpacing.sm),
              CheckboxListTile(
                key: const ValueKey('salawat-never'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: never,
                title: Text(l10n.salawatDontShow),
                onChanged: (v) => setState(() => never = v ?? false),
              ),
            ],
          ),
          actions: [
            FilledButton(
              key: const ValueKey('salawat-close'),
              onPressed: () => Navigator.of(context).pop(never),
              child: Text(l10n.tipClose),
            ),
          ],
        ),
      );
    },
  );
  if (off ?? false) {
    await container.read(salawatReminderProvider.notifier).setEnabled(false);
  }
}
