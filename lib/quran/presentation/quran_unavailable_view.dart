import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_store/app_store_service.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../application/quran_setup.dart';

/// Where the Quran should be but isn't. When setting it up on the phone
/// failed ([quranSetupProvider]): that it failed, the error itself (kept on
/// screen for as long as it lasts, to be screenshotted), a way to try again
/// and one to share the details.
class QuranUnavailableView extends ConsumerWidget {
  const QuranUnavailableView({super.key, this.icon = Icons.menu_book_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(quranSetupProvider);
    final failure = setup.failure;
    if (failure == null && !setup.retrying) {
      return TahfeezEmptyView(
        icon: icon,
        message: l10n.homeQuranDatasetUnavailableBody,
      );
    }
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value ?? '?';
    return TahfeezEmptyView(
      key: const ValueKey('quran-setup-failed'),
      icon: Icons.error_outline_rounded,
      message: setup.storageFull
          ? l10n.quranSetupStorageFull
          : l10n.quranSetupFailed,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: TahfeezSpacing.md,
        children: [
          if (failure != null)
            SelectableText(
              failure.length > 600 ? '${failure.substring(0, 600)}…' : failure,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('quran-setup-retry'),
                onPressed: setup.retrying
                    ? null
                    : () => ref.read(quranSetupProvider.notifier).retry(),
                icon: setup.retrying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(l10n.quranSetupRetry),
              ),
              if (failure != null)
                TextButton.icon(
                  onPressed: () => ref
                      .read(appStoreServiceProvider)
                      .share(quranSetupReport(failure, version: version)),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.quranSetupShare),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
