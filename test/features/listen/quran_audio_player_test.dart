import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_focus_ayah.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';

import '../../test_helpers/fake_audio_controller.dart';

void main() {
  test('from an ayah to the surah\'s end: the playing ayah is highlighted; '
      'stop clears it', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        // No Mushaf to follow in these tests.
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final player = container.read(quranAudioPlayerProvider.notifier);

    expect(await player.playFrom(112002), isTrue);
    expect(audio.queue, hasLength(3), reason: '112:2 to 112:4');
    expect(audio.queue.first, endsWith('/ar.alafasy/6223.mp3'));
    expect(container.read(quranAudioPlayerProvider)?.ayahId, 112002);
    expect(container.read(mushafFocusAyahProvider)?.ayahId, 112002);

    audio.advanceTo(2);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(quranAudioPlayerProvider)?.ayahId, 112004);
    expect(container.read(mushafFocusAyahProvider)?.ayahId, 112004);

    await player.stop();
    expect(container.read(quranAudioPlayerProvider), isNull);
    expect(container.read(mushafFocusAyahProvider), isNull);
  });

  test('each ayah is titled for the media notification; a stop from it '
      'clears what plays', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await container.read(quranAudioPlayerProvider.notifier).playFrom(112002);
    expect(audio.items, hasLength(3));
    expect(audio.items!.first.title, '112 · 2');
    expect(audio.items!.first.subtitle, 'Mishary Alafasy');

    audio.stopFromOutside();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(quranAudioPlayerProvider), isNull);
  });

  test('a word plays alone, without highlighting an ayah', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        // No Mushaf to follow in these tests.
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(quranAudioPlayerProvider.notifier).playWord(1001, 0),
      isTrue,
    );
    expect(container.read(quranAudioPlayerProvider)?.isWord, isTrue);
    expect(container.read(mushafFocusAyahProvider), isNull);
  });

  test('repeats: each ayah, then the whole range', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        // No Mushaf to follow in these tests.
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(quranAudioPlayerProvider.notifier)
        .playRange(
          112001,
          112002,
          options: const ListenOptions(ayahRepeats: 2, rangeRepeats: 2),
        );
    expect(container.read(quranAudioPlayerProvider)?.ayahIds, [
      112001, 112001, 112002, 112002, //
      112001, 112001, 112002, 112002,
    ]);
  });

  test('a range runs across surah ends', () {
    expect(ayahRange(113005, 114002), [113005, 114001, 114002]);
    expect(ayahRange(114002, 114001), isEmpty);
  });

  test('leaving the Mushaf stops it', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        // No Mushaf to follow in these tests.
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final target = container.read(mushafRecitationTargetProvider.notifier);
    final owner = Object();
    target.show(owner, const QuranLocation.page(1, 604));
    await container.read(quranAudioPlayerProvider.notifier).playFrom(112001);
    expect(container.read(quranAudioPlayerProvider), isNotNull);
    target.clear(owner);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(quranAudioPlayerProvider), isNull);
  });

  test('a new run isn\'t ended by the previous item\'s "completed" (the '
      'bar and highlight stay)', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final player = container.read(quranAudioPlayerProvider.notifier);
    await player.playWord(1001, 0);
    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(quranAudioPlayerProvider), isNull);

    // The player still says "completed" as the run starts.
    await player.playFrom(112001);
    audio.advanceTo(0);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(quranAudioPlayerProvider)?.ayahId, 112001);
    expect(container.read(mushafFocusAyahProvider)?.ayahId, 112001);
  });
}
