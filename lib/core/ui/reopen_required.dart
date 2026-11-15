import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/generated/app_localizations.dart';
import '../platform/app_reload.dart';
import '../core_providers.dart';
import '../theme/app_spacing.dart';

/// Why the app must start over: a backup imported, or all data reset.
enum DataReplaced { imported, reset }

/// The app's data replaced underneath it: everything read before is out of
/// date, and saving it would write the old over the new (2026-11-15: on
/// iOS, a backup's activity counts and bookmarks overwritten by the
/// running app's). Set, the app is covered until it is opened again.
class ReopenRequiredController extends Notifier<DataReplaced?> {
  @override
  DataReplaced? build() => null;

  void set(DataReplaced why) => state = why;
}

final reopenRequiredProvider =
    NotifierProvider<ReopenRequiredController, DataReplaced?>(
      ReopenRequiredController.new,
    );

/// The app's data replaced ([why]): it starts over — Android closes it
/// (opened again, it reads the new data), the web page loads again; iOS
/// can't quit an app, so it is covered by a request to reopen it, nothing
/// usable (or saved) meanwhile.
Future<void> startOverAfterDataReplaced(WidgetRef ref, DataReplaced why) async {
  if (ref.read(platformCapabilitiesProvider).isAndroid) {
    await SystemNavigator.pop();
    return;
  }
  if (reloadApp()) return;
  ref.read(reopenRequiredProvider.notifier).set(why);
}

/// Over the whole app once its data was replaced ([reopenRequiredProvider]):
/// what happened, and to close and reopen it — nothing beneath reachable.
class ReopenRequiredLayer extends ConsumerWidget {
  const ReopenRequiredLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final why = ref.watch(reopenRequiredProvider);
    if (why == null) return child;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Material(
        key: const ValueKey('reopen-required'),
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(TahfeezSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TahfeezSpacing.md,
                  children: [
                    Icon(
                      Icons.restart_alt_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    Text(
                      why == DataReplaced.imported
                          ? l10n.settingsImportDone
                          : l10n.settingsResetDone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      l10n.settingsReopenToFinish,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
