import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/follow_along_controller.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/sajdah_reminder.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_session.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart' show HifzVerdict;
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../../test_helpers/fake_audio_controller.dart';

/// The microphone session: started and stopped, nothing recorded.
class _FakeSession extends RecitationSessionController {
  var starts = 0;

  @override
  RecitationSessionState build() => const RecitationSessionState();

  @override
  Future<void> start({QuranLocation? startLocation}) async {
    starts++;
    state = const RecitationSessionState(phase: RecitationPhase.listening);
  }

  @override
  Future<RecitationSession?> stop() async {
    state = const RecitationSessionState();
    return null;
  }
}

/// The test: its loop recorded; its progress set by the test.
class _FakeHifz extends HifzController {
  HifzRange? loopRange;
  HifzLoop? loop;

  @override
  HifzState build() => const HifzState();

  @override
  void setLoop(HifzRange range, HifzLoop loop) {
    loopRange = range;
    this.loop = loop;
  }

  void set(HifzState s) => state = s;
}

void main() {
  late FakeAudioController audio;
  late ProviderContainer container;
  late _FakeSession session;
  late _FakeHifz hifz;

  setUp(() {
    audio = FakeAudioController();
    container = ProviderContainer(
      overrides: [
        audioControllerProvider.overrideWithValue(audio),
        defaultMushafProvider.overrideWith((ref) async => null),
        recitationSessionControllerProvider.overrideWith(_FakeSession.new),
        hifzControllerProvider.overrideWith(_FakeHifz.new),
      ],
    );
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show(Object(), const QuranLocation.page(1, 604));
    // The bar keeps these alive.
    container.listen(followAlongControllerProvider, (_, _) {});
    container.listen(recitationSessionControllerProvider, (_, _) {});
    session = container.read(
      recitationSessionControllerProvider.notifier,
    ) as _FakeSession;
    hifz = container.read(hifzControllerProvider.notifier) as _FakeHifz;
  });
  tearDown(() => container.dispose());

  FollowAlongState? run() => container.read(followAlongControllerProvider);

  /// The user's turn recited, every repetition.
  Future<void> userRecites(int count) async {
    hifz.set(
      HifzState(
        completed: true,
        loop: HifzLoop(mode: HifzLoopMode.range, count: count),
        repetition: count,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    hifz.set(const HifzState());
  }

  test('each ayah: the reciter twice, then the user once, then the next '
      'ayah; done after the last', () async {
    final started = await container
        .read(followAlongControllerProvider.notifier)
        .start(
          (chapterNo: 112, verseNo: 1),
          (chapterNo: 112, verseNo: 2),
          const FollowAlongOptions(reciterTimes: 2, speed: 0.75),
        );
    expect(started, isTrue);
    expect(audio.queue, hasLength(2), reason: '112:1 twice');
    expect(container.read(quranAudioPlayerProvider)?.ayahIds, [112001, 112001]);
    expect(run()!.phase, FollowAlongPhase.reciter);

    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(run()!.phase, FollowAlongPhase.user);
    expect(session.starts, 1);
    expect(hifz.loopRange, (
      from: (chapterNo: 112, verseNo: 1),
      to: (chapterNo: 112, verseNo: 1),
    ));
    expect(hifz.loop!.count, 1);

    // A loop's earlier pass completing is not the turn's end.
    hifz.set(
      const HifzState(
        completed: true,
        loop: HifzLoop(mode: HifzLoopMode.range, count: 2),
        repetition: 1,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(run()!.phase, FollowAlongPhase.user);
    hifz.set(const HifzState());

    await userRecites(1);
    expect(run()!.index, 1);
    expect(run()!.phase, FollowAlongPhase.reciter);
    expect(container.read(quranAudioPlayerProvider)?.ayahIds, [112002, 112002]);

    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(run()!.phase, FollowAlongPhase.user);
    await userRecites(1);
    expect(run(), isNull, reason: 'the last ayah done');
  });

  test('the whole range at once', () async {
    await container
        .read(followAlongControllerProvider.notifier)
        .start(
          (chapterNo: 112, verseNo: 1),
          (chapterNo: 112, verseNo: 4),
          const FollowAlongOptions(unit: FollowAlongUnit.range, userTimes: 3),
        );
    expect(run()!.parts, hasLength(1));
    expect(audio.queue, hasLength(4));
    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(hifz.loopRange!.to, (chapterNo: 112, verseNo: 4));
    expect(hifz.loop!.count, 3);
  });

  test('stopping the reciter, or the user\'s turn, ends the run', () async {
    final follow = container.read(followAlongControllerProvider.notifier);
    await follow.start(
      (chapterNo: 112, verseNo: 1),
      (chapterNo: 112, verseNo: 4),
      const FollowAlongOptions(),
    );
    await container.read(quranAudioPlayerProvider.notifier).stop();
    expect(run(), isNull);

    await follow.start(
      (chapterNo: 112, verseNo: 1),
      (chapterNo: 112, verseNo: 4),
      const FollowAlongOptions(),
    );
    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(run()!.phase, FollowAlongPhase.user);
    await session.stop();
    expect(run(), isNull);
  });

  group('the Sujood al-Tilawah reminder', () {
    setUp(resetSajdahReminderForTest);

    const w = (ayahId: 96019, wordIndex: 0);
    const tested = HifzState(
      first: (ayahId: 96015, wordIndex: 0),
      last: (ayahId: 96019, wordIndex: 3),
    );

    HifzState at(WordRef? expected, {bool completed = false}) => HifzState(
      first: tested.first,
      last: tested.last,
      marked: const {w: HifzVerdict.correct},
      expected: expected,
      completed: completed,
    );

    test('after the ayah of prostration is recited, once', () async {
      container.listen(sajdahReminderProvider, (_, _) {});
      hifz.set(at(const (ayahId: 96019, wordIndex: 1)));
      expect(
        container.read(sajdahReminderProvider),
        isNull,
        reason: 'still in the ayah',
      );
      hifz.set(at(null, completed: true));
      expect(container.read(sajdahReminderProvider), 96019);
    });

    test('off in Hifz settings: never', () async {
      container.listen(sajdahReminderProvider, (_, _) {});
      final settings = container.read(hifzSettingsProvider.notifier);
      settings.update(
        container.read(hifzSettingsProvider).copyWith(sajdahReminder: false),
      );
      hifz.set(at(null, completed: true));
      expect(container.read(sajdahReminderProvider), isNull);
    });
  });
}
