import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_loop_sheet.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const VerseRef ayah = (chapterNo: 2, verseNo: 255);

  test('each ayah: the times left of the ayah, this one included', () {
    const loop = HifzLoop(count: 3);
    expect(
      loopTimesLeft(
        const HifzState(loop: loop, repetition: 1, loopAyah: ayah),
        l10n,
      ),
      '2:255 · 3 times left',
    );
    expect(
      loopTimesLeft(
        const HifzState(loop: loop, repetition: 3, loopAyah: ayah),
        l10n,
      ),
      '2:255 · Last time',
    );
  });

  test('a whole range ayah by ayah: the ayah\'s times in this pass; '
      'without, the passes left', () {
    expect(
      loopTimesLeft(
        const HifzState(
          loop: HifzLoop(mode: HifzLoopMode.range, count: 5, perAyah: 3),
          repetition: 4,
          loopAyah: ayah,
          ayahRepetition: 2,
        ),
        l10n,
      ),
      '2:255 · 2 times left',
    );
    expect(
      loopTimesLeft(
        const HifzState(
          loop: HifzLoop(mode: HifzLoopMode.range, count: 5),
          repetition: 4,
        ),
        l10n,
      ),
      '2 times left',
    );
  });

  test('no loop under way, or one done: nothing', () {
    expect(loopTimesLeft(const HifzState(), l10n), isNull);
    expect(
      loopTimesLeft(
        const HifzState(loop: HifzLoop(), repetition: 3, completed: true),
        l10n,
      ),
      isNull,
    );
  });

  test('a loop in one sentence, before it starts', () {
    expect(
      loopPlan(const HifzLoop(count: 3), l10n),
      'Each ayah 3 times, then the next. The last time is checked: with a '
      'mistake, try again or skip.',
    );
    expect(
      loopPlan(const HifzLoop(count: 1), l10n),
      startsWith('Each ayah once, then the next.'),
    );
    expect(
      loopPlan(
        const HifzLoop(mode: HifzLoopMode.range, count: 2, perAyah: 3),
        l10n,
      ),
      startsWith('The whole range 2 times. Each ayah 3 times in a row.'),
    );
  });
}
