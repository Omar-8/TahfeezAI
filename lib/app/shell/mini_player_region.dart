import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_controller.dart';
import '../../core/audio/audio_models.dart';
import '../../core/core_providers.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../../core/theme/tahfeez_motion.dart';
import '../../features/listen/application/quran_audio_player.dart';
import '../../features/quran/application/quran_index_providers.dart';

/// Home information-hierarchy item 6: "persistent mini-player region when
/// active." Mounted once at the app-shell level (`app_shell.dart`), not
/// inside `HomeScreen`, so it survives switching between Home/Quran/Search
/// — an explicit improvement over the reference app's own Activity-boundary
/// limitation flagged in `docs/reference/03_NAVIGATION_MAP.md` §7.
///
/// Wired to the real [AudioController] (Milestone 1's minimal `just_audio`
/// implementation), not a fake state — but since nothing in the app calls
/// `playUrl` yet (there is no Reader/verse-audio UI before later
/// milestones), this renders its zero-height "no active track" state in
/// production today. [AudioPlaybackState.durationMs] being non-null is
/// used as the "a track is loaded" signal (it's only set once a URL has
/// actually been played), so the region reserves space only while genuinely
/// active rather than a permanently-empty placeholder gap.
class MiniPlayerRegion extends ConsumerWidget {
  const MiniPlayerRegion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.watch(audioControllerProvider);
    final nowPlaying = ref.watch(quranAudioPlayerProvider);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final ayahId = nowPlaying?.ayahId;
    final surahName = ayahId == null
        ? null
        : [
            for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
              if (s.surah.surahNo == ayahId ~/ 1000)
                s.localizedName ?? s.arabicName,
          ].firstOrNull;
    final reciter = nowPlaying?.reciter;

    return StreamBuilder<AudioPlaybackState>(
      stream: controller.state,
      initialData: const AudioPlaybackState(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AudioPlaybackState();
        // A single word plays without the player bar.
        final isActive =
            state.durationMs != null && !(nowPlaying?.isWord ?? false);

        return AnimatedSize(
          duration: TahfeezMotionDuration.medium,
          curve: TahfeezMotionCurves.standard,
          alignment: Alignment.bottomCenter,
          child: !isActive
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TahfeezSpacing.md,
                    0,
                    TahfeezSpacing.md,
                    TahfeezSpacing.sm,
                  ),
                  child: TahfeezMiniPlayerShell(
                    title: ayahId == null
                        ? l10n.miniPlayerDefaultTitle
                        : l10n.homeDailyAyahReferenceNamed(
                            surahName ?? '${ayahId ~/ 1000}',
                            ayahId % 1000,
                          ),
                    subtitle: reciter == null
                        ? null
                        : (arabic ? reciter.nameAr : reciter.nameEn),
                    isPlaying: state.isPlaying,
                    progress: (state.durationMs ?? 0) > 0
                        ? state.positionMs / state.durationMs!
                        : null,
                    onPlayPause: () {
                      if (state.isPlaying) {
                        controller.pause();
                      } else {
                        controller.resume();
                      }
                    },
                    closeTooltip: l10n.listenStop,
                    onClose: () =>
                        ref.read(quranAudioPlayerProvider.notifier).stop(),
                  ),
                ),
        );
      },
    );
  }
}
