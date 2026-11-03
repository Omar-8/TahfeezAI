import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/ui/first_run.dart';
import '../listen/application/follow_along_controller.dart';
import '../listen/application/quran_audio_player.dart';
import '../listen/presentation/listen_sheet.dart';
import '../mushaf/presentation/mushaf_appearance_sheet.dart';
import '../recitation/application/recitation_session_controller.dart';
import 'app_tips.dart';
import 'guide.dart';

/// In the reader's top bar, nothing to see: offers the reader's tips (see
/// [AppTip]) when they fit — the page themes a while after the reader
/// opens, nothing playing; a translation read aloud a while into
/// listening, none chosen. One at most each time the reader is open.
class AppTipsHost extends ConsumerStatefulWidget {
  const AppTipsHost({super.key});

  /// How long the reader is open, or the reciter heard, before a tip.
  static const readingDelay = Duration(seconds: 20);
  static const listeningDelay = Duration(seconds: 30);

  @override
  ConsumerState<AppTipsHost> createState() => _AppTipsHostState();
}

class _AppTipsHostState extends ConsumerState<AppTipsHost> {
  Timer? _reading, _listening;
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(firstRunPromptsProvider)) return;
    unawaited(
      appTipsStart(
        ref.read(browserStorageProvider),
        ref.read(appTipsClockProvider)(),
      ),
    );
    _reading = Timer(AppTipsHost.readingDelay, () {
      if (_busy() || _playing()) return;
      unawaited(_offer(AppTip.pageTheme));
    });
  }

  @override
  void dispose() {
    _reading?.cancel();
    _listening?.cancel();
    super.dispose();
  }

  /// The reciter heard (ayahs, not a word).
  bool _playing() {
    final now = ref.read(quranAudioPlayerProvider);
    return now != null && !now.isWord;
  }

  /// Something else on: the guide, a recitation, Follow along, or another
  /// screen or sheet over the reader.
  bool _busy() =>
      _offered ||
      !mounted ||
      ref.read(guideProvider) != null ||
      (ref.exists(recitationSessionControllerProvider) &&
          ref.read(recitationSessionControllerProvider).isActive) ||
      (ref.exists(followAlongControllerProvider) &&
          ref.read(followAlongControllerProvider) != null) ||
      !(ModalRoute.of(context)?.isCurrent ?? true);

  void _listen(NowPlaying? previous, NowPlaying? next) {
    final playing = next != null && !next.isWord;
    if (!playing) {
      _listening?.cancel();
      _listening = null;
      return;
    }
    if (_listening != null || !ref.read(firstRunPromptsProvider)) return;
    _listening = Timer(AppTipsHost.listeningDelay, () {
      final now = ref.read(quranAudioPlayerProvider);
      if (_busy() || now == null || now.isWord) return;
      if (now.options.translationVoice.isNotEmpty) return;
      unawaited(_offer(AppTip.listenTranslation));
    });
  }

  Future<void> _offer(AppTip tip) async {
    final storage = ref.read(browserStorageProvider);
    final due = await appTipDue(
      storage,
      tip,
      now: ref.read(appTipsClockProvider)(),
      random: ref.read(appTipsRandomProvider),
    );
    if (!due || _busy() || !mounted) return;
    _offered = true;
    final answer = await showAppTip(context, tip);
    if (answer == null) return;
    if (answer.never || answer.showMe) await appTipOff(storage, tip);
    if (!answer.showMe || !mounted) return;
    switch (tip) {
      case AppTip.listenTranslation:
        // From the ayah playing: Play goes on with the translation.
        final ayah = ref.read(quranAudioPlayerProvider)?.ayahId;
        unawaited(
          showListenSheet(
            context,
            from: ayah == null
                ? null
                : (chapterNo: ayah ~/ 1000, verseNo: ayah % 1000),
          ),
        );
        ref.read(guideProvider.notifier).start(GuideTour.tipTranslation);
      case AppTip.pageTheme:
        showMushafAppearanceSheet(context);
        ref.read(guideProvider.notifier).start(GuideTour.tipPageTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NowPlaying?>(quranAudioPlayerProvider, _listen);
    return const SizedBox.shrink();
  }
}

/// A tip: "Show me" or Close, and "Don't show this again". `null`:
/// dismissed (back, or a tap outside).
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
