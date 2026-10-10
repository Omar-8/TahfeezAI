import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_store/app_store_service.dart';
import '../../../core/app_store/store_prompts.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../memorization/application/activity_stats.dart';

/// Once per app session, a moment after Home first shows: offers an update
/// if Google Play has one (see [StorePrompts]); otherwise, now and then,
/// asks for a rating. Draws nothing.
class HomeStorePrompts extends ConsumerStatefulWidget {
  const HomeStorePrompts({super.key});

  @override
  ConsumerState<HomeStorePrompts> createState() => _HomeStorePromptsState();
}

/// Run already this app session.
var _ran = false;

class _HomeStorePromptsState extends ConsumerState<HomeStorePrompts> {
  @override
  void initState() {
    super.initState();
    if (_ran) return;
    _ran = true;
    // Once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    final prompts = ref.read(storePromptsProvider);
    if (await prompts.shouldOfferUpdate()) {
      if (mounted) await showUpdateOffer(context, ref);
      return;
    }
    await prompts.maybeAskForReview(
      recitedAyahs: ref.read(activityStatsProvider).recitedAyahs,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "A new version is available": update (Google Play's screen) or later.
Future<void> showUpdateOffer(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final update = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('update-offer'),
      icon: const Icon(Icons.system_update_rounded),
      title: Text(l10n.updateTitle),
      content: Text(l10n.updateBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.updateLater),
        ),
        FilledButton(
          key: const ValueKey('update-now'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.updateNow),
        ),
      ],
    ),
  );
  if (update ?? false) {
    unawaited(ref.read(appStoreServiceProvider).update());
  } else {
    await ref.read(storePromptsProvider).snoozeUpdate();
  }
}
