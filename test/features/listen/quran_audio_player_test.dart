import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_focus_ayah.dart';

import '../../test_helpers/fake_audio_controller.dart';

void main() {
  test('from an ayah to the surah\'s end: the playing ayah is highlighted; '
      'stop clears it', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [audioControllerProvider.overrideWithValue(audio)],
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

  test('a word plays alone, without highlighting an ayah', () async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [audioControllerProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(quranAudioPlayerProvider.notifier).playWord(1001, 0),
      isTrue,
    );
    expect(container.read(quranAudioPlayerProvider)?.isWord, isTrue);
    expect(container.read(mushafFocusAyahProvider), isNull);
  });
}
