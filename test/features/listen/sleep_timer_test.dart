import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/listen/application/sleep_timer.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';

import '../../test_helpers/fake_audio_controller.dart';

/// The sleep timer: listening paused after the minutes chosen, or at the
/// end of the ayah playing; gone when listening ends.
void main() {
  late FakeAudioController audio;
  late ProviderContainer container;
  final paused = <bool>[];

  void setUpPlayer() {
    audio = FakeAudioController();
    paused.clear();
    audio.state.listen((s) => paused.add(!s.isPlaying));
    container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        defaultMushafProvider.overrideWith((ref) async => null),
      ],
    );
    container.listen(sleepTimerProvider, (_, _) {});
  }

  test(
    'after the minutes chosen: paused (not stopped), and the timer gone',
    () {
      fakeAsync((async) {
        setUpPlayer();
        container.read(quranAudioPlayerProvider.notifier).playFrom(2001);
        async.flushMicrotasks();
        container.read(sleepTimerProvider.notifier).setMinutes(15);
        expect(container.read(sleepTimerProvider)?.minutes, 15);
        async.elapse(const Duration(minutes: 14, seconds: 59));
        expect(paused.lastOrNull, isFalse);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(paused.last, isTrue, reason: 'paused');
        expect(
          container.read(quranAudioPlayerProvider),
          isNotNull,
          reason: 'not stopped: Play resumes',
        );
        expect(container.read(sleepTimerProvider), isNull);
        container.dispose();
      });
    },
  );

  test('at the end of this ayah: paused when the next one begins', () {
    fakeAsync((async) {
      setUpPlayer();
      container.read(quranAudioPlayerProvider.notifier).playFrom(112001);
      async.flushMicrotasks();
      container.read(sleepTimerProvider.notifier).setAfterAyah();
      expect(container.read(sleepTimerProvider)?.afterAyah, isTrue);
      audio.advanceTo(1);
      async.flushMicrotasks();
      expect(paused.last, isTrue);
      expect(container.read(sleepTimerProvider), isNull);
      container.dispose();
    });
  });

  test('stopping the recitation clears it; nothing then pauses', () {
    fakeAsync((async) {
      setUpPlayer();
      final player = container.read(quranAudioPlayerProvider.notifier);
      player.playFrom(2001);
      async.flushMicrotasks();
      container.read(sleepTimerProvider.notifier).setMinutes(30);
      player.stop();
      async.flushMicrotasks();
      expect(container.read(sleepTimerProvider), isNull);
      player.playFrom(2001);
      async.flushMicrotasks();
      final before = paused.length;
      async.elapse(const Duration(minutes: 31));
      expect(paused.skip(before), isNot(contains(true)));
      container.dispose();
    });
  });

  test('nothing playing: "end of this ayah" is not set', () {
    setUpPlayer();
    addTearDown(container.dispose);
    container.read(sleepTimerProvider.notifier).setAfterAyah();
    expect(container.read(sleepTimerProvider), isNull);
  });

  test('at the end of this ayah, with its translation read after it: paused '
      'once the translation has played too', () {
    fakeAsync((async) {
      setUpPlayer();
      container
          .read(quranAudioPlayerProvider.notifier)
          .playRange(
            // (Not from 112:1: no Bismillah before it here.)
            112002,
            112004,
            options: const ListenOptions(translationVoice: 'en.walk'),
          );
      async.flushMicrotasks();
      container.read(sleepTimerProvider.notifier).setAfterAyah();
      audio.advanceTo(1); // its translation
      async.flushMicrotasks();
      expect(container.read(sleepTimerProvider), isNotNull);
      audio.advanceTo(2); // the next ayah
      async.flushMicrotasks();
      expect(paused.last, isTrue);
      expect(container.read(sleepTimerProvider), isNull);
      container.dispose();
    });
  });
}
