import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_start.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../../../test_helpers/real_app.dart';
import '../../recitation/live_recognition_controller_test.dart'
    show FakeRecognizer;
import '../../recitation/recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

/// Ayah mode as the printed page: with the ayahs hidden, the blue band on
/// the next word to recite, moving as words and ayahs are revealed (owner,
/// 2026-11-20: it stayed behind).
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  for (final layout in AyahLayout.values) {
    testWidgets('${layout.name}: revealing moves the band to the next word '
        'to recite', (tester) async {
      final container = await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        mode: ReaderMode.ayah,
        layout: layout,
      );
      WordRef? band() {
        final o = container.read(mushafWordOverlayProvider);
        return o?.marks.entries
            .where((e) => e.value == MushafWordMark.current)
            .map((e) => e.key)
            .firstOrNull;
      }

      final hide = container.read(mushafHideModeProvider.notifier);
      hide.toggle();
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 0));

      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 1));
      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 2));

      // A whole ayah: the band on the next ayah's first word.
      hide.revealNextAyah(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1002, wordIndex: 0));

      // And drawn: that word's band in Ayah mode itself.
      expect(find.byKey(const ValueKey('ayah-word-1002:0')), findsOneWidget);
      // Hide mode and where the next recitation starts are kept on the
      // phone: as they were, for the next test.
      container.read(mushafHideModeProvider.notifier).toggle();
      container.read(recitationStartProvider.notifier).clear();
      await RealApp.settle(tester);
      await RealApp.quit(tester);
    });
  }

  /// A word chosen (tapped, or where a recitation or the reciter stopped):
  /// the band on it while it is hidden, then on as it is uncovered (owner,
  /// 2026-11-21: after a recitation, revealing no longer moved it).
  for (final layout in AyahLayout.values) {
    testWidgets('${layout.name}: a chosen word, uncovered, gives way — the '
        'band on to the next word to uncover', (tester) async {
      final container = await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        mode: ReaderMode.ayah,
        layout: layout,
      );
      WordRef? band() {
        final o = container.read(mushafWordOverlayProvider);
        return o?.band ??
            o?.marks.entries
                .where((e) => e.value == MushafWordMark.current)
                .map((e) => e.key)
                .firstOrNull;
      }

      final hide = container.read(mushafHideModeProvider.notifier);
      hide.toggle();
      await RealApp.settle(tester);
      // As a stopped recitation leaves it: the next word, 1:1's third.
      container.read(recitationStartProvider.notifier).choose((
        ayahId: 1001,
        wordIndex: 2,
      ));
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 2));

      // The words before it uncovered: the band stays on it (2026-11-15).
      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 2));
      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 2));
      // It uncovered: on to the next, and on with each reveal.
      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 3));
      expect(container.read(recitationStartProvider), isNull);
      hide.revealNextWord(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1002, wordIndex: 0));
      hide.revealNextAyah(1);
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1003, wordIndex: 0));
      expect(
        tester
            .widget<AyahWordView>(
              find.byKey(const ValueKey('ayah-word-1003:0')),
            )
            .mark,
        MushafWordMark.current,
        reason: 'drawn',
      );

      container.read(mushafHideModeProvider.notifier).toggle();
      container.read(recitationStartProvider.notifier).clear();
      await RealApp.settle(tester);
      await RealApp.quit(tester);
    });
  }

  /// The band during a recitation, the ayahs hidden (owner, 2026-11-20:
  /// "while reciting", the reveal buttons uncovered words but the band
  /// stayed).
  for (final layout in AyahLayout.values) {
    testWidgets('${layout.name}, reciting: the reveal buttons move the band', (
      tester,
    ) async {
      final container = await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        mode: ReaderMode.ayah,
        layout: layout,
        overrides: [
          recitationSupportedProvider.overrideWithValue(true),
          recitationAudioSourceFactoryProvider.overrideWithValue(
            FakeAudioSource.new,
          ),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          liveQuranRecognizerFactoryProvider.overrideWithValue(
            FakeRecognizer.new,
          ),
          liveRecognitionEnabledProvider.overrideWithValue(true),
          liveRecognitionDevPanelEnabledProvider.overrideWithValue(false),
          memorizationRecordDelayProvider.overrideWithValue(Duration.zero),
          memorizationRecorderProvider.overrideWithValue((_) async {}),
          // The first recitation's explanation already seen.
          hifzSettingsProvider.overrideWith(_IntroSeen.new),
        ],
      );
      WordRef? band() {
        final o = container.read(mushafWordOverlayProvider);
        return o?.marks.entries
            .where((e) => e.value == MushafWordMark.current)
            .map((e) => e.key)
            .firstOrNull;
      }

      // The band as drawn: the word's own mark.
      MushafWordMark? drawn(int ayahId, int wordIndex) => tester
          .widget<AyahWordView>(
            find.byKey(ValueKey('ayah-word-$ayahId:$wordIndex')),
          )
          .mark;

      container.read(mushafHideModeProvider.notifier).toggle();
      await RealApp.settle(tester);
      // Recite, from the modes (the bar folded, the ayahs hidden).
      await tester.tap(find.byTooltip('Recitation modes'));
      await RealApp.settle(tester);
      await tester.tap(find.byKey(const ValueKey('modes-menu-recite')));
      await RealApp.settle(tester);
      expect(container.read(hifzControllerProvider).active, isTrue);
      expect(band(), (ayahId: 1001, wordIndex: 0));

      expect(drawn(1001, 0), MushafWordMark.current);
      await tester.tap(find.byTooltip('Reveal next word'));
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1001, wordIndex: 1));
      expect(drawn(1001, 1), MushafWordMark.current);
      expect(drawn(1001, 0), isNot(MushafWordMark.current));
      await tester.tap(find.byTooltip('Reveal next ayah'));
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1002, wordIndex: 0));
      expect(drawn(1002, 0), MushafWordMark.current);
      expect(drawn(1001, 1), isNot(MushafWordMark.current));
      await tester.tap(find.byTooltip('Stop'));
      await RealApp.settle(tester);

      // Recited again: from where the last stopped (its next word), the
      // buttons moving the band as before.
      await tester.tap(find.byTooltip('Recitation modes'));
      await RealApp.settle(tester);
      await tester.tap(find.byKey(const ValueKey('modes-menu-recite')));
      await RealApp.settle(tester);
      expect(container.read(hifzControllerProvider).active, isTrue);
      expect(band(), (ayahId: 1002, wordIndex: 0));
      await tester.tap(find.byTooltip('Reveal next word'));
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1002, wordIndex: 1));
      expect(drawn(1002, 1), MushafWordMark.current);
      await tester.tap(find.byTooltip('Reveal next ayah'));
      await RealApp.settle(tester);
      expect(band(), (ayahId: 1003, wordIndex: 0));
      expect(drawn(1003, 0), MushafWordMark.current);
      await tester.tap(find.byTooltip('Stop'));
      await RealApp.settle(tester);
      // Hide mode and where the next recitation starts are kept on the
      // phone: as they were, for the next test.
      container.read(mushafHideModeProvider.notifier).toggle();
      container.read(recitationStartProvider.notifier).clear();
      await RealApp.settle(tester);
      await RealApp.quit(tester);
    });
  }
}

class _IntroSeen extends HifzSettingsController {
  @override
  HifzSettings build() =>
      HifzSettings(introsSeen: RecitationIntroMode.values.toSet());
}
