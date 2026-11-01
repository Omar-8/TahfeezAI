import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/acoustic/quran_acoustic_verifier.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../listen/application/reciter_controller.dart';
import '../../listen/domain/word_timings.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import '../application/acoustic_verification_controller.dart';
import 'recitation_controls.dart';

/// What the last recitation found wrong in [wordRef] — a different word, a
/// skip, or the pronunciation mistakes heard in it (each on its letter of
/// [wordText]) — for the word's detail sheet. Nothing for a word recited
/// correctly or not recited.
class RecitationWordFeedback extends ConsumerWidget {
  const RecitationWordFeedback({
    super.key,
    required this.wordRef,
    this.wordText,
  });

  final WordRef wordRef;

  /// The word's canonical Uthmani text, to name the letter of a mistake.
  final String? wordText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(mushafWordOverlayProvider);
    final mark = overlay?.marks[wordRef];
    final l10n = AppLocalizations.of(context);
    final List<String> lines;
    // A mistake on the word's first letter: its correction starts at the
    // word before, which may join into it.
    var onFirstLetter = false;
    switch (mark) {
      case MushafWordMark.wrong:
        final heard = overlay!.heard[wordRef];
        lines = [
          if (overlay.corrected.contains(wordRef)) l10n.recFeedbackCorrected,
          if (heard != null && readablePhonetic(heard).isNotEmpty)
            l10n.recFeedbackHeardInstead(readablePhonetic(heard))
          else if (!overlay.corrected.contains(wordRef))
            l10n.recFeedbackWrongWord,
        ];
      case MushafWordMark.skipped:
        lines = [l10n.recFeedbackSkipped];
      case MushafWordMark.tashkeel ||
          MushafWordMark.tajweed ||
          MushafWordMark.checking:
        final errors = [
          for (final e
              in ref
                      .watch(acousticVerificationControllerProvider)
                      .words[wordRef]
                      ?.errors ??
                  const <RecitationError>[])
            if (e.type.isError) e,
        ];
        onFirstLetter = errors.any((e) => e.letter == 0);
        lines = errors.isEmpty
            ? [l10n.recFeedbackPronunciation]
            : {
                // (one mistake may show as two: a nūn heard and the
                // merged letter single — the same idgham)
                for (final e in errors)
                  _onLetter(e, l10n, HifzStatusStrip.describe(e, l10n)),
              }.take(3).toList();
      default:
        return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('recitation-word-feedback'),
      padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          Icon(
            Icons.record_voice_over_outlined,
            color: scheme.onErrorContainer,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TahfeezSpacing.xs,
              children: [
                Text(
                  l10n.recFeedbackTitle,
                  style: text.labelLarge?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                _ListenToCorrection(
                  wordRef: wordRef,
                  fromPrevious: onFirstLetter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [detail], said on the mistake's letter when the word's text names it.
  String _onLetter(RecitationError e, AppLocalizations l10n, String detail) {
    final letters = baseLetters(wordText ?? '');
    if (e.letter < 0 || e.letter >= letters.length) return _capital(detail);
    return l10n.recFeedbackOnLetter(letters[e.letter], detail);
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// "Listen to the correction": the word as the chosen reciter recites it,
/// joined to the next word — or, for a reciter without word timings, the
/// word alone, said so beneath.
class _ListenToCorrection extends ConsumerWidget {
  const _ListenToCorrection({
    required this.wordRef,
    required this.fromPrevious,
  });

  final WordRef wordRef;
  final bool fromPrevious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final timed = hasWordTimings(ref.watch(reciterProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const ValueKey('recitation-word-listen'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onErrorContainer,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.volume_up_outlined),
          label: Text(l10n.recFeedbackListen),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final played = await ref
                .read(quranAudioPlayerProvider.notifier)
                .playCorrection(
                  wordRef.ayahId,
                  wordRef.wordIndex,
                  fromPrevious: fromPrevious,
                );
            if (played == CorrectionPlayback.failed) {
              showListenOffline(messenger, l10n.listenOffline);
            }
          },
        ),
        if (!timed)
          Text(
            l10n.recFeedbackListenAlone,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onErrorContainer),
          ),
      ],
    );
  }
}

/// The phonetic script the recognizer hears in (Quran Phonetic Script),
/// made readable as plain Arabic: its long-vowel and nasal signs as
/// letters, its tajweed markers (qalqala, sakt, imala …) left out.
String readablePhonetic(String heard) => heard
    .replaceAll('ۦ', 'ي')
    .replaceAll('ۥ', 'و')
    .replaceAll('ں', 'ن')
    .replaceAll(RegExp('[ڇؙۜ۾ٲـ۪]'), '')
    .trim();

/// The base letters of an Uthmani word, in order — the positions the
/// phonetic reference counts a mistake's letter in (`build_reference.py`:
/// Arabic letters, alif wasla and the dagger alif; not tatweel or marks).
List<String> baseLetters(String word) => [
  for (final c in word.runes.map(String.fromCharCode))
    if ((c.compareTo('ء') >= 0 && c.compareTo('ي') <= 0 && c != 'ـ') ||
        c == 'ٱ' ||
        c == 'ٰ')
      c,
];
