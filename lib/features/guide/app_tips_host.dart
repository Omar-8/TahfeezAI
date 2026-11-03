import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/storage/storage_providers.dart';
import '../listen/application/follow_along_controller.dart';
import '../listen/application/quran_audio_player.dart';
import '../mushaf/presentation/mushaf_appearance_sheet.dart';
import '../recitation/application/recitation_session_controller.dart';
import 'app_tips.dart';
import 'guide.dart';

/// In the reader's top bar, nothing to see: the page themes' tip (see
/// [AppTip]) a while after the reader opens — nothing playing, nothing
/// recited. The modes' tips come as they are started (Listen's Play,
/// Recite, the loop, Follow along), never while they run.
class AppTipsHost extends ConsumerStatefulWidget {
  const AppTipsHost({super.key});

  /// How long the reader is open before the tip.
  static const readingDelay = Duration(seconds: 20);

  @override
  ConsumerState<AppTipsHost> createState() => _AppTipsHostState();
}

class _AppTipsHostState extends ConsumerState<AppTipsHost> {
  Timer? _reading;

  @override
  void initState() {
    super.initState();
    if (!ref.read(appTipsEnabledProvider)) return;
    unawaited(
      appTipsStart(
        ref.read(browserStorageProvider),
        ref.read(appTipsClockProvider)(),
      ),
    );
    _reading = Timer(AppTipsHost.readingDelay, () {
      if (_busy()) return;
      unawaited(_offer());
    });
  }

  @override
  void dispose() {
    _reading?.cancel();
    super.dispose();
  }

  /// Something else on: the guide, a recitation, Follow along, the
  /// reciter heard, or another screen or sheet over the reader.
  bool _busy() {
    if (!mounted) return true;
    final playing = ref.read(quranAudioPlayerProvider);
    return ref.read(guideProvider) != null ||
        (playing != null && !playing.isWord) ||
        (ref.exists(recitationSessionControllerProvider) &&
            ref.read(recitationSessionControllerProvider).isActive) ||
        (ref.exists(followAlongControllerProvider) &&
            ref.read(followAlongControllerProvider) != null) ||
        !(ModalRoute.of(context)?.isCurrent ?? true);
  }

  Future<void> _offer() async {
    final due = await appTipDue(
      ref.read(browserStorageProvider),
      AppTip.pageTheme,
      now: ref.read(appTipsClockProvider)(),
      random: ref.read(appTipsRandomProvider),
    );
    if (!due || !mounted || _busy()) return;
    if (!await answerAppTip(context, ref, AppTip.pageTheme) || !mounted) {
      return;
    }
    showMushafAppearanceSheet(context);
    ref.read(guideProvider.notifier).start(GuideTour.tipPageTheme);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Whether tips may come now: on ([appTipsEnabledProvider]), not in the
/// guide.
bool appTipsAllowed(WidgetRef ref) =>
    ref.read(appTipsEnabledProvider) && ref.read(guideProvider) == null;

/// Shows [tip] and keeps its answer: "Don't show tips again" ends them all;
/// "Show me" (returned `true`) — the tip is known, not shown again.
Future<bool> answerAppTip(
  BuildContext context,
  WidgetRef ref,
  AppTip tip,
) async {
  final storage = ref.read(browserStorageProvider);
  final answer = await showAppTip(context, tip);
  if (answer == null) return false;
  if (answer.never) await appTipsAllOff(storage);
  if (answer.showMe) await appTipOff(storage, tip);
  return answer.showMe;
}

/// A tip: "Show me" or Close, and "Don't show tips again". `null`:
/// dismissed (back, or a tap outside) — as Close.
Future<({bool showMe, bool never})?> showAppTip(
  BuildContext context,
  AppTip tip,
) {
  var never = false;
  return showDialog<({bool showMe, bool never})>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          key: ValueKey('app-tip-${tip.name}'),
          icon: const Icon(Icons.lightbulb_outline),
          title: Text(l10n.recHintTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (tip) {
                AppTip.listenTranslation => l10n.tipListenTranslation,
                AppTip.pageTheme => l10n.tipPageTheme,
                AppTip.tajweedOff => l10n.tipTajweedOff,
                AppTip.lenient => l10n.tipLenient,
              }),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey('app-tip-never'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: never,
                title: Text(l10n.tipDontShowAgain),
                onChanged: (v) => setState(() => never = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('app-tip-close'),
              onPressed: () =>
                  Navigator.of(context).pop((showMe: false, never: never)),
              child: Text(l10n.tipClose),
            ),
            FilledButton(
              key: const ValueKey('app-tip-show'),
              onPressed: () =>
                  Navigator.of(context).pop((showMe: true, never: never)),
              child: Text(l10n.tipShowMe),
            ),
          ],
        ),
      );
    },
  );
}
