import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../application/meaning_packs.dart';
import '../data/import/meaning_pack_store.dart';

/// "1.2 MB", "480 KB": a pack's download.
String meaningPackSize(int bytes) => bytes >= 1000 * 1000
    ? '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB'
    : '${(bytes / 1000).round()} KB';

/// Beside a translation, tafsir or word-meaning set in its list: on the
/// phone, a button to delete it; not, one to download it (with its size);
/// downloading, a spinner; built in (English's, Arabic's), nothing. Nothing
/// at all where packs aren't downloads (the web).
class MeaningPackAction extends ConsumerWidget {
  const MeaningPackAction({super.key, required this.kind, required this.id});

  final MeaningPackKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(meaningPackInfoProvider(kind)).value?[id];
    if (info == null || info.status == MeaningPackStatus.builtIn) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final packs = ref.read(meaningPacksProvider.notifier);
    return switch (info.status) {
      MeaningPackStatus.downloading => const SizedBox(
        key: ValueKey('meaning-pack-downloading'),
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      MeaningPackStatus.installed => IconButton(
        key: const ValueKey('meaning-pack-delete'),
        tooltip: l10n.commonDelete,
        icon: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onPressed: () => packs.delete(kind, id),
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.bytes case final bytes?)
            Text(
              meaningPackSize(bytes),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          IconButton(
            key: const ValueKey('meaning-pack-download'),
            tooltip: l10n.meaningPackDownload,
            icon: Icon(Icons.download_rounded, color: scheme.primary),
            // In use already (waiting for the network): tried again;
            // otherwise downloaded and kept.
            onPressed: () =>
                ref
                    .read(meaningPacksProvider)
                    .missing
                    .contains(meaningPackKey(kind, id))
                ? packs.retry()
                : packs.download(kind, id),
          ),
        ],
      ),
    };
  }
}
