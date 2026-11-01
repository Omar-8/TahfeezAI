import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_controller.dart';
import 'package:tahfeez_ai/features/listen/data/word_timings_repository.dart';
import 'package:tahfeez_ai/features/listen/domain/word_timings.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';

import '../../test_helpers/fake_audio_controller.dart';

/// Word timings that are given, not fetched (or fail, as offline).
class _Timings implements WordTimingsRepository {
  _Timings(this.spans, {this.offline = false});

  final Map<int, WordSpan> spans;
  final bool offline;

  @override
  Future<AyahWordTimings?> timings(String edition, int ayahId) async {
    if (offline) throw Exception('offline');
    if (quranComSurahRecitations.containsKey(edition)) {
      // The ayah 10 s into its surah's recording.
      return AyahWordTimings(
        {
          for (final e in spans.entries)
            e.key: (
              startMs: e.value.startMs + 10000,
              endMs: e.value.endMs + 10000,
            ),
        },
        surahUrl: 'https://surah.example/018.mp3',
        fromMs: 10000 + 800,
        toMs: 10000 + 3950,
      );
    }
    return quranComRecitations.containsKey(edition)
        ? AyahWordTimings(spans)
        : null;
  }
}

/// A recitation mistake's correction: the word as the reciter recites it,
/// with its neighbour — Quran.com's word timings over the reciter's ayah.
void main() {
  // 18:10's first four words, as Quran.com times Alafasy's.
  final spans = parseWordSegments([
    [0, 1, 900, 1330],
    ['1', '2', '1340', '1860'],
    [2, 3, 1870, 3370],
    [3, 4, 3380, 3920],
  ]);

  test('segments: numbers or numeric strings; the malformed left out', () {
    expect(spans[2], (startMs: 1340, endMs: 1860));
    expect(spans, hasLength(4));
    expect(
      parseWordSegments([
        [0, 1, 500, 400], // ends before it starts
        [0, 2], // too short
        'x',
      ]),
      isEmpty,
    );
    expect(parseWordSegments(null), isEmpty);
  });

  test('the word and the next one, with a lead and a tail', () {
    expect(correctionClip(AyahWordTimings(spans), 2), (
      startMs: 1190,
      endMs: 3670,
    ));
  });

  test('from the word before for a mistake on the first letter', () {
    expect(correctionClip(AyahWordTimings(spans), 2, fromPrevious: true), (
      startMs: 750,
      endMs: 3670,
    ));
    // The first word has none before it.
    expect(correctionClip(AyahWordTimings(spans), 1, fromPrevious: true), (
      startMs: 750,
      endMs: 2160,
    ));
  });

  test('the last word alone (the reciter stops on it); none untimed', () {
    expect(correctionClip(AyahWordTimings(spans), 4), (
      startMs: 3230,
      endMs: 4220,
    ));
    expect(correctionClip(AyahWordTimings(spans), 9), isNull);
    // Never before the file's start.
    expect(
      correctionClip(
        const AyahWordTimings({1: (startMs: 40, endMs: 300)}),
        1,
      )?.startMs,
      0,
    );
  });

  test('surah segments ([word, start, end], fractions too)', () {
    expect(
      parseWordSegments([
        [1, 0.0, 660.0],
        [2, 660.4, 960.6],
      ]),
      {1: (startMs: 0, endMs: 660), 2: (startMs: 660, endMs: 961)},
    );
  });

  test('in a surah recording, kept within the ayah', () {
    final inSurah = AyahWordTimings(
      {1: (startMs: 10900, endMs: 11330), 2: (startMs: 11340, endMs: 11860)},
      surahUrl: 'x',
      fromMs: 10850,
      toMs: 11900,
    );
    // Not back into the ayah before, nor on into the next.
    expect(correctionClip(inSurah, 1, fromPrevious: true), (
      startMs: 10750,
      endMs: 12050,
    ));
  });

  test('only reciters Quran.com times have timings', () {
    expect(hasWordTimings('ar.alafasy'), isTrue);
    expect(hasWordTimings('ar.husarymuallim'), isTrue);
    expect(hasWordTimings('ar.dossary'), isTrue);
    expect(hasWordTimings('ar.tunaiji'), isTrue);
    expect(hasWordTimings('ar.ghamdi'), isFalse);
    expect(wordTimingsUrl(7, 18010), endsWith('/recitations/7/by_ayah/18:10'));
  });

  group('playCorrection', () {
    ({ProviderContainer container, FakeAudioController audio}) setUp(
      _Timings timings,
    ) {
      final audio = FakeAudioController();
      final container = ProviderContainer(
        overrides: [
          audioControllerProvider.overrideWithValue(audio),
          defaultMushafProvider.overrideWith((ref) async => null),
          wordTimingsRepositoryProvider.overrideWithValue(timings),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, audio: audio);
    }

    test('a timed reciter: cut from the ayah it recites', () async {
      final (:container, :audio) = setUp(_Timings(spans));
      final played = await container
          .read(quranAudioPlayerProvider.notifier)
          .playCorrection(18010, 1);
      expect(played, CorrectionPlayback.reciter);
      final (url, start, end) = audio.clip!;
      expect(url, endsWith('/ar.alafasy/2150.mp3'));
      expect(start, const Duration(milliseconds: 1190));
      expect(end, const Duration(milliseconds: 3670));
      expect(audio.url, isNull);
      expect(container.read(quranAudioPlayerProvider)?.isWord, isTrue);
    });

    test(
      'a reciter timed by surah: cut from that surah\'s recording',
      () async {
        final (:container, :audio) = setUp(_Timings(spans));
        await container.read(reciterProvider.notifier).select('ar.dossary');
        final played = await container
            .read(quranAudioPlayerProvider.notifier)
            .playCorrection(18010, 1);
        expect(played, CorrectionPlayback.reciter);
        final (url, start, end) = audio.clip!;
        expect(url, 'https://surah.example/018.mp3');
        expect(start, const Duration(milliseconds: 11190));
        expect(end, const Duration(milliseconds: 13670));
      },
    );

    test('an untimed reciter: the word alone', () async {
      final timings = _Timings(spans);
      final (:container, :audio) = setUp(timings);
      await container.read(reciterProvider.notifier).select('ar.ghamdi');
      final played = await container
          .read(quranAudioPlayerProvider.notifier)
          .playCorrection(18010, 1);
      expect(played, CorrectionPlayback.wordAlone);
      expect(audio.clip, isNull);
      expect(audio.url, endsWith('/wbw/018_010_002.mp3'));
    });

    test('timings not fetched (offline): the word alone', () async {
      final (:container, :audio) = setUp(_Timings(spans, offline: true));
      final played = await container
          .read(quranAudioPlayerProvider.notifier)
          .playCorrection(18010, 1);
      expect(played, CorrectionPlayback.wordAlone);
      expect(audio.url, endsWith('/wbw/018_010_002.mp3'));
    });
  });
}
