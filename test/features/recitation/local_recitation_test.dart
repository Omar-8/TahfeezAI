import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_model_manifest.dart';
import 'package:tahfeez_ai/ai/acoustic/local_quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/remote_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/screen_awake.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/ai/speech/unavailable_live_recognizer.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_position_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_position.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/domain/repositories/quran_repository.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/local_acoustic_inference_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_ai_config.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import '../../ai/acoustic/local_quran_acoustic_model_test.dart'
    show manifestJson;
import '../../ai/acoustic/acoustic_test_support.dart';
import '../../ai/matching/corpus_fixture.dart';
import '../../ai/matching/position_fixture_support.dart';
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

/// Offline, on the device: what an Android build with
/// `TAHFEEZ_OFFLINE_RECITATION=true` resolves to.
final offlineAndroid = resolveRecitationAiConfig(
  backendName: '',
  positionName: '',
  comparator: false,
  offline: true,
  onDevice: true,
  release: false,
);

class _MemoryStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}

  final values = <String, Object>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Frame `i` of each run carries `i` in its blank column, so a test can
/// see which part of a window was kept.
class _FakeModel extends LocalQuranAcousticModel {
  final runs = <int>[];

  /// Called during each run (audio arriving meanwhile).
  void Function()? during;

  @override
  Future<LocalAcousticModelStatus> status() async => LocalAcousticModelStatus(
    LocalAcousticModelState.present,
    path: '/fake',
    manifest: AcousticModelManifest.fromJson(manifestJson()),
  );

  @override
  Future<AcousticModelLoad> load() async => const AcousticModelLoad(
    provider: AcousticExecutionProvider.cpu,
    loadTime: Duration(milliseconds: 5),
  );

  @override
  Future<AcousticFrames> run(Float32List samples) async {
    runs.add(samples.length);
    if (during case final during?) {
      during();
      await Future<void>.delayed(Duration.zero);
    }
    final n = samples.length ~/ 640;
    final lp = Float32List(n * 43);
    for (var i = 0; i < n; i++) {
      lp[i * 43] = i.toDouble();
    }
    return AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: lp,
      frameDuration: const Duration(milliseconds: 40),
    );
  }

  @override
  Future<AcousticDeviceStats?> deviceStats() async => null;
}

/// A streaming model (v3): 1.28 s chunks with 240 samples after each; each
/// run's frames carry whether it was committed (blank log-prob 1) or a
/// provisional look at a partial chunk (-1).
class _FakeStreamingModel extends _FakeModel {
  final commits = <bool>[];
  var resets = 0;

  @override
  AcousticStreamConfig get stream => const AcousticStreamConfig(
    chunkSamples: 20480,
    overlapSamples: 240,
    chunkSeconds: 1.28,
    leftSeconds: 5.12,
  );

  @override
  Future<void> streamReset() async => resets++;

  @override
  Future<AcousticFrames> streamRun(
    Float32List samples, {
    bool commit = true,
  }) async {
    runs.add(samples.length);
    commits.add(commit);
    const n = 32;
    final lp = Float32List(n * 43);
    for (var i = 0; i < n; i++) {
      lp[i * 43] = commit ? 1 : -1;
    }
    return AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: lp,
      frameDuration: const Duration(milliseconds: 40),
    );
  }
}

class _FakeScreen implements ScreenAwake {
  final calls = <bool>[];
  @override
  Future<void> keepOn(bool on) async => calls.add(on);
}

/// Recorded frames as the pipeline's store, and noise as its audio (the
/// verifier reads both).
class _RecordedInference extends _ReplayInference {
  _RecordedInference(this.recorded, {this.stored = false});

  final AcousticFrames recorded;

  /// The frames are in [store] too, as the pipeline would have computed
  /// them (for the quick per-word checks).
  final bool stored;
  final requests = <(int, int)>[];

  @override
  LocalAcousticInferenceState build() {
    final rng = Random(1);
    final bytes = Uint8List(recorded.frames * 640 * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length ~/ 2; i++) {
      view.setInt16(i * 2, rng.nextInt(4000) - 2000, Endian.little);
    }
    pcm.addPcm16(bytes);
    if (stored) store.add(TimedAcousticFrames(0, recorded));
    return super.build();
  }

  @override
  Future<TimedAcousticFrames?> framesFor(
    int from,
    int to, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final first = (from + 639) ~/ 640, last = to ~/ 640;
    requests.add((first, last));
    return TimedAcousticFrames(first, recorded.slice(first, last - 1));
  }
}

/// A model run over a piece: the recorded frames of the audio it was given
/// (found by its samples in the session's audio, which is unique noise).
class _RecordedModel extends _FakeModel {
  _RecordedModel(this.inference);
  final _RecordedInference inference;

  /// The stream frames of every run: (first, one past the last).
  final pieces = <(int, int)>[];

  @override
  Future<AcousticFrames> run(Float32List samples) async {
    final all = inference.pcm.samples(0, inference.pcm.written);
    var at = -1;
    for (var i = 0; i + 8 <= all.length && at < 0; i++) {
      var same = true;
      for (var k = 0; k < 8 && same; k++) {
        same = all[i + k] == samples[k];
      }
      if (same) at = i;
    }
    expect(at, isNot(-1), reason: 'the piece is session audio');
    final first = (at + 639) ~/ 640;
    final n = samples.length ~/ 640;
    final last = (first + n).clamp(first + 1, inference.recorded.frames);
    pieces.add((first, last));
    return inference.recorded.slice(first, last - 1);
  }
}

/// Publishes recorded frames instead of running a model.
class _ReplayInference extends LocalAcousticInferenceController {
  _ReplayInference();

  final out = StreamController<TimedAcousticFrames>.broadcast();

  @override
  LocalAcousticInferenceState build() => const LocalAcousticInferenceState();

  @override
  Stream<TimedAcousticFrames> get frames => out.stream;
}

void main() {
  group('recitation AI configuration', () {
    test('Android defaults to the on-device model and tracker', () {
      final c = resolveRecitationAiConfig(
        backendName: '',
        positionName: '',
        comparator: false,
        offline: false,
        onDevice: true,
        release: true,
      );
      expect(c.acoustic, QuranAcousticBackend.local);
      expect(c.position, RecitationPositionSource.acoustic);
      expect(c.speechRecognizerRuns, isFalse, reason: 'no Google');
      expect(c.violation, isNull);
    });

    test('the web keeps the speech recognizer; no local model yet', () {
      final dev = resolveRecitationAiConfig(
        backendName: '',
        positionName: '',
        comparator: false,
        offline: false,
        onDevice: false,
        release: false,
      );
      expect(dev.acoustic, QuranAcousticBackend.remoteDevelopment);
      expect(dev.position, RecitationPositionSource.speechRecognizer);
      final release = resolveRecitationAiConfig(
        backendName: '',
        positionName: '',
        comparator: false,
        offline: false,
        onDevice: false,
        release: true,
      );
      expect(release.acoustic, QuranAcousticBackend.disabled);
    });

    test('offline refuses the remote model, Google and the comparator', () {
      final c = resolveRecitationAiConfig(
        backendName: 'remote',
        positionName: 'speech',
        comparator: true,
        offline: true,
        onDevice: false,
        release: false,
      );
      expect(c.acoustic, QuranAcousticBackend.disabled);
      expect(c.speechRecognizerRuns, isFalse);
      expect(c.speechComparator, isFalse);
      expect(c.violation, contains('remote acoustic model'));
      expect(c.violation, contains('speech recognizer'));
      expect(c.violation, contains('comparator'));
    });

    test('the Google comparator runs beside the acoustic tracker', () {
      final c = resolveRecitationAiConfig(
        backendName: 'local',
        positionName: '',
        comparator: true,
        offline: false,
        onDevice: true,
        release: false,
      );
      expect(c.position, RecitationPositionSource.acoustic);
      expect(c.speechRecognizerRuns, isTrue);
    });

    test('offline Android: no recognizer, no remote model', () {
      final container = ProviderContainer(
        overrides: [
          recitationAiConfigProvider.overrideWithValue(offlineAndroid),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(liveQuranRecognizerFactoryProvider)(),
        isA<UnavailableLiveRecognizer>(),
      );
      expect(
        container.read(quranAcousticModelProvider),
        isA<LocalQuranAcousticModel>(),
      );
      expect(
        container.read(quranAcousticModelProvider),
        isNot(isA<RemoteAcousticModel>()),
      );
    });
  });

  group('LocalAcousticInferenceController', () {
    late FakeAudioSource mic;
    late _FakeModel model;
    late _FakeScreen screen;
    late ProviderContainer container;
    final chunks = <TimedAcousticFrames>[];

    RecitationSessionController session() =>
        container.read(recitationSessionControllerProvider.notifier);
    LocalAcousticInferenceController inference() =>
        container.read(localAcousticInferenceControllerProvider.notifier);

    setUp(() async {
      mic = FakeAudioSource();
      model = _FakeModel();
      screen = _FakeScreen();
      chunks.clear();
      container = ProviderContainer(
        overrides: [
          recitationAiConfigProvider.overrideWithValue(offlineAndroid),
          recitationAudioSourceFactoryProvider.overrideWithValue(() => mic),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          localQuranAcousticModelProvider.overrideWithValue(model),
          screenAwakeProvider.overrideWithValue(screen),
          // These tests check the pipeline at 2 s hops with 1 s of context.
          acousticWindowingProvider.overrideWithValue(
            const AcousticWindowing(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(localAcousticInferenceControllerProvider, (_, _) {});
      inference().frames.listen(chunks.add);
      await pumpEventQueue();
      expect(
        container.read(localAcousticInferenceControllerProvider).ready,
        isTrue,
      );
      await session().start(startLocation: const QuranLocation.page(1, 440));
      await pumpEventQueue();
    });

    Future<void> speak(double seconds) async {
      for (var t = 0.0; t < seconds; t += 0.5) {
        mic.emitSeconds(0.5, value: 3);
        await pumpEventQueue();
      }
    }

    test('one pipeline: contiguous, deduplicated, bounded windows', () async {
      await speak(12);
      // Frames up to 1 s before the live edge, never a gap or a repeat.
      var next = 0;
      for (final c in chunks) {
        expect(c.start, next);
        next = c.end;
      }
      expect(next, greaterThanOrEqualTo((12 - 1 - 2) * 25));
      expect(next, lessThanOrEqualTo((12 - 1) * 25));
      // Each window ran ≤ 6 s new + 1 s each side, and kept its middle:
      // after the first, kept frames start 25 frames (1 s) into the run.
      expect(model.runs.every((n) => n <= 8 * 16000), isTrue);
      expect(chunks.first.frames.at(0, 0), 0);
      for (final c in chunks.skip(1)) {
        expect(c.frames.at(0, 0), 25);
      }
      final state = container.read(localAcousticInferenceControllerProvider);
      expect(state.windows, chunks.length);
      expect(state.rtf, isNotNull);
    });

    test('pausing computes the tail at once and marks it last', () async {
      await speak(5);
      session().pause();
      await pumpEventQueue(times: 50);
      expect(chunks.last.last, isTrue);
      expect(chunks.last.end, 5 * 25);
      // The screen stays on while listening (off, the app is moved to the
      // slow cores), and is released on pause.
      expect(screen.calls, [true, false]);
    });

    test(
      'a pause in speech computes up to it at once, then hops resume',
      () async {
        // 0.1 s of a 400 Hz tone (speech), or of silence.
        void emit(bool loud) {
          final pcm = ByteData(3200);
          for (var t = 0; t < 1600; t++) {
            final x = loud ? (8000 * sin(2 * pi * 400 * t / 16000)).round() : 0;
            pcm.setInt16(t * 2, x, Endian.little);
          }
          mic.mic!.add(pcm.buffer.asUint8List());
        }

        Future<void> say(double seconds, {required bool loud}) async {
          for (var t = 0.0; t < seconds - 1e-9; t += 0.1) {
            emit(loud);
            await pumpEventQueue();
          }
        }

        await say(5, loud: true); // speech…
        // …then silence, with audio arriving while the model runs.
        model.during = () => emit(false);
        final before = model.runs.length;
        await say(0.5, loud: false);
        // The stop was heard (0.3 s of quiet): the audio up to it is
        // computed and marked last, without waiting for the context after it.
        debugPrint(
          [for (final c in chunks) "${c.start}-${c.end}${c.last ? "L" : ""}"]
              .join(" "),
        );
        final mark = chunks.lastIndexWhere((c) => c.last);
        expect(mark, isNot(-1));
        expect(chunks[mark].end, inInclusiveRange(5 * 25, 5 * 25 + 10));
        await say(4, loud: false);
        // Not chasing the live edge: 4.5 s of audio, a few windows (2 s hops).
        expect(model.runs.length - before, lessThanOrEqualTo(5));
        var next = 0;
        for (final c in chunks) {
          expect(c.start, next);
          next = c.end;
        }
      },
    );

    test('the verifier reuses the computed frames', () async {
      await speak(8);
      final runsBefore = model.runs.length;
      final reused = await inference().framesFor(16000, 4 * 16000);
      expect(reused!.start, 25);
      expect(reused.frames.frames, 75);
      expect(model.runs.length, runsBefore, reason: 'no model run');
    });
  });

  group('LocalAcousticInferenceController, streaming model', () {
    late FakeAudioSource mic;
    late _FakeStreamingModel model;
    late ProviderContainer container;
    final chunks = <TimedAcousticFrames>[];

    RecitationSessionController session() =>
        container.read(recitationSessionControllerProvider.notifier);
    LocalAcousticInferenceController inference() =>
        container.read(localAcousticInferenceControllerProvider.notifier);

    setUp(() async {
      mic = FakeAudioSource();
      model = _FakeStreamingModel();
      chunks.clear();
      container = ProviderContainer(
        overrides: [
          recitationAiConfigProvider.overrideWithValue(offlineAndroid),
          recitationAudioSourceFactoryProvider.overrideWithValue(() => mic),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          localQuranAcousticModelProvider.overrideWithValue(model),
          screenAwakeProvider.overrideWithValue(_FakeScreen()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(localAcousticInferenceControllerProvider, (_, _) {});
      inference().frames.listen(chunks.add);
      await pumpEventQueue();
      await session().start(startLocation: const QuranLocation.page(1, 440));
      await pumpEventQueue();
    });

    Future<void> speak(double seconds) async {
      for (var t = 0.0; t < seconds - 1e-9; t += 0.5) {
        mic.emitSeconds(0.5, value: 3);
        await pumpEventQueue();
      }
    }

    test(
      'each chunk of audio is run once, as soon as it has arrived',
      () async {
        await speak(6);
        expect(model.resets, 1);
        // 6 s: four whole 1.28 s chunks (each needs 240 samples after it).
        expect(model.runs, List.filled(4, 20480 + 240));
        expect(model.commits, everyElement(isTrue));
        var next = 0;
        for (final c in chunks) {
          expect(c.start, next);
          expect(c.frames.frames, 32);
          expect(c.last, isFalse);
          next = c.end;
        }
        expect(inference().store.end, 4 * 32);
      },
    );

    test('a paused session computes its partial chunk provisionally, then the '
        'real chunk replaces it', () async {
      await speak(5);
      session().pause();
      await pumpEventQueue(times: 50);
      // 3 whole chunks (3.84 s), then 1.16 s of a fourth, provisional.
      expect(model.commits, [true, true, true, false]);
      expect(chunks.last.last, isTrue);
      expect(chunks.last.start, 3 * 32);
      expect(chunks.last.end, 5 * 25);
      expect(inference().store.slice(96, 125)!.frames.at(0, 0), -1);
      session().resume();
      await pumpEventQueue();
      await speak(2);
      // The same chunk, now whole and committed: its frames replace the
      // provisional ones; the timeline stays the recitation's.
      expect(model.commits.skip(4), everyElement(isTrue));
      final store = inference().store;
      expect(store.slice(96, 128)!.frames.at(0, 0), 1);
      expect(store.slice(96, 128)!.frames.at(28, 0), 1);
      expect(model.resets, 1, reason: 'same session: state kept');
    });
  });

  group('Hifz on the device, Google off', () {
    final corpus = loadTestCorpus();
    late ProviderContainer container;
    late _ReplayInference inference;

    HifzState hifz() => container.read(hifzControllerProvider);

    Future<void> setUpHifz({
      bool range = true,
      ({int chapterNo, int verseNo})? to,
      _RecordedInference? recorded,
      HifzLoop? loop,
      // The page on screen, its first and last ayah (default: page 42,
      // 2:253–2:256); and hide mode.
      (int, int, int)? page,
      bool hidden = false,
    }) async {
      inference = recorded ?? _ReplayInference();
      container = ProviderContainer(
        overrides: [
          recitationAiConfigProvider.overrideWithValue(offlineAndroid),
          recitationAudioSourceFactoryProvider.overrideWithValue(
            FakeAudioSource.new,
          ),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          quranWordCorpusProvider.overrideWith((ref) async => corpus),
          quranPhonemeResourcesProvider.overrideWith(
            (ref) async => loadTestPhonemes(),
          ),
          localAcousticInferenceControllerProvider.overrideWith(
            () => inference,
          ),
          quranAcousticModelProvider.overrideWithValue(
            recorded == null ? null : _RecordedModel(recorded),
          ),
          quranPhoneticReferenceProvider.overrideWith(
            (ref) async => loadTestReference(),
          ),
          browserStorageProvider.overrideWithValue(_MemoryStorage()),
          hifzHapticsProvider.overrideWithValue(() {}),
          quranRepositoryProvider.overrideWithValue(_NoPages()),
          memorizationRecordDelayProvider.overrideWithValue(Duration.zero),
          memorizationRecorderProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(container.dispose);
      // Page 42 (2:253–2:256) is on screen, or [page].
      final (number, a, b) = page ?? (42, 2253, 2256);
      final first = corpus.verseStartPosition((
        chapterNo: a ~/ 1000,
        verseNo: a % 1000,
      ))!;
      final last = corpus.verseEndPosition((
        chapterNo: b ~/ 1000,
        verseNo: b % 1000,
      ))!;
      container
          .read(mushafRecitationTargetProvider.notifier)
          .show('screen', QuranLocation.page(1, number));
      container.read(mushafPageWordRangesProvider.notifier).report(number, (
        first: corpus.words[first].ref,
        last: corpus.words[last].ref,
      ));
      if (hidden) container.read(mushafHideModeProvider.notifier).toggle();
      container.listen(liveRecognitionControllerProvider, (_, _) {});
      container.listen(hifzControllerProvider, (_, _) {});
      container.listen(acousticVerificationControllerProvider, (_, _) {});
      await container.read(quranWordCorpusProvider.future);
      await container.read(quranPhonemeResourcesProvider.future);
      if (range) {
        final chosen = (
          from: (chapterNo: 36, verseNo: 1),
          to: to ?? (chapterNo: 36, verseNo: 5),
        );
        final controller = container.read(hifzControllerProvider.notifier);
        if (loop != null) {
          controller.setLoop(chosen, loop);
        } else {
          controller.setRange(chosen);
        }
      }
      await container
          .read(recitationSessionControllerProvider.notifier)
          .start(startLocation: const QuranLocation.page(1, 42));
      await pumpEventQueue();
    }

    Future<void> play(String scenario, {int at = 0}) async {
      final s = PositionScenario.all()[scenario]!;
      final frames = s.frames();
      var start = 0;
      for (final (i, end) in s.chunkEnds.indexed) {
        inference.out.add(
          TimedAcousticFrames(
            at + start,
            frames.slice(start, end - 1),
            last: i == s.chunkEnds.length - 1,
          ),
        );
        start = end;
        await pumpEventQueue();
      }
    }

    test('a range test: false start, self-correction, completion', () async {
      await setUpHifz();
      expect(
        container.read(liveRecognitionControllerProvider).recognizerName,
        'None',
        reason: 'Google is off',
      );
      await play('self_correction');
      expect(hifz().counts[HifzVerdict.skipped], 1);
      expect(hifz().counts[HifzVerdict.selfCorrected], 1);
      expect(hifz().counts[HifzVerdict.wrong], 0);
      expect(hifz().completed, isTrue);
    });

    test(
      'recited words appear one after another, never several at once',
      () async {
        await setUpHifz(to: (chapterNo: 36, verseNo: 8));
        var shown = 0, most = 0;
        container.listen(mushafWordOverlayProvider, (_, next) {
          final n = next?.revealed.length ?? 0;
          if (n - shown > most) most = n - shown;
          shown = n;
        });
        await play('page_start');
        for (var i = 0; i < 100 && shown < hifz().revealed.length; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(hifz().revealed, hasLength(37));
        expect(shown, 37, reason: 'all shown in the end');
        expect(most, 1);
      },
    );

    test('a loop: the range followed again from its start', () async {
      await setUpHifz(
        to: (chapterNo: 36, verseNo: 8),
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2),
      );
      await play('page_start');
      expect(hifz().repetition, 2);
      expect(hifz().expected, (ayahId: 36001, wordIndex: 0));
      expect(hifz().running, isTrue);
      // The same recitation again, later in the session.
      await play(
        'page_start',
        at: PositionScenario.all()['page_start']!.chunkEnds.last,
      );
      expect(hifz().completed, isTrue);
      expect(hifz().counts[HifzVerdict.correct], 37);
      expect(container.read(recitationPassProvider), 1);
    });

    test('every ayah is checked for pronunciation, on a run over its own '
        'audio with margin', () async {
      final frames = PositionScenario.all()['page_start']!.frames();
      final recorded = _RecordedInference(frames);
      await setUpHifz(to: (chapterNo: 36, verseNo: 8), recorded: recorded);
      await play('page_start');
      for (var i = 0; i < 200; i++) {
        await pumpEventQueue();
        final a = container.read(acousticVerificationControllerProvider);
        if (a.pending == 0 && a.words.length >= 37) break;
      }
      final acoustic = container.read(acousticVerificationControllerProvider);
      // All 8 ayahs (37 words) judged — none skipped for want of audio.
      expect(acoustic.words.length, 37);
      expect(acoustic.words.keys.map((w) => w.ayahId).toSet(), {
        for (var v = 1; v <= 8; v++) 36000 + v,
      });
      // Each ayah ran the model once over its own audio (a whole-piece run,
      // as calibrated), not on the streaming windows' frames.
      final model =
          container.read(quranAcousticModelProvider)! as _RecordedModel;
      expect(model.pieces.length, greaterThanOrEqualTo(8));
      expect(recorded.requests, isEmpty);
      // Clean recitation: (almost) nothing flagged.
      final flagged = acoustic.words.values.where((w) => w.isMistake).length;
      expect(flagged, lessThanOrEqualTo(2));
      expect(
        acoustic.words.values.where(
          (w) => w.type == RecitationErrorType.correct,
        ),
        hasLength(greaterThan(30)),
      );
    });

    test('a clear mistake is marked once the next word begins, then '
        'confirmed by its ayah\'s check', () async {
      // 36:2 «وَٱلْقُرْءَانِ» said with ك for its ق (the first ق heard).
      final clean = PositionScenario.all()['page_start']!.frames();
      final q = phoneticClassOf('ق'), k = phoneticClassOf('ك');
      final said = Float32List.fromList(clean.logProbs);
      final c = clean.classes;
      var f = 0;
      while (_argmax(said, f, c) != q) {
        f++;
      }
      for (; _argmax(said, f, c) == q; f++) {
        final (a, b) = (said[f * c + q], said[f * c + k]);
        said[f * c + q] = b;
        said[f * c + k] = a;
      }
      final recorded = _RecordedInference(
        AcousticFrames(
          frames: clean.frames,
          classes: c,
          logProbs: said,
          frameDuration: clean.frameDuration,
        ),
        stored: true,
      );
      await setUpHifz(to: (chapterNo: 36, verseNo: 8), recorded: recorded);
      const word = (ayahId: 36002, wordIndex: 0);
      // The word's verdicts as they come.
      final seen = <AcousticWordResult>[];
      container.listen(acousticVerificationControllerProvider, (_, next) {
        final w = next.words[word];
        if (w != null && (seen.isEmpty || seen.last != w)) seen.add(w);
      });
      await play('page_start');
      for (var i = 0; i < 200; i++) {
        await pumpEventQueue();
        final a = container.read(acousticVerificationControllerProvider);
        if (a.pending == 0 && a.words.length >= 37) break;
      }
      // First an early mark, then the ayah's check confirms it…
      expect(
        [for (final w in seen) (w.type, w.provisional)],
        [
          (RecitationErrorType.wrongLetter, true),
          (RecitationErrorType.wrongLetter, false),
        ],
      );
      // …and decides every word.
      final a = container.read(acousticVerificationControllerProvider);
      expect(a.words.values.where((w) => w.provisional), isEmpty);
      expect(a.words, hasLength(37));
    });

    test(
      'hide mode: a reciter starting further down the page is picked up '
      'there, the ayahs before given — not skipped, not revealed by hand',
      () async {
        // Ya-Sin 36:1–36:12 on screen, hidden; the reciter begins at 36:9
        // (as Al-Hadid after Al-Waqi'a's last ayahs).
        await setUpHifz(range: false, page: (440, 36001, 36012), hidden: true);
        expect(
          hifz().expected,
          corpus
              .words[corpus.verseStartPosition((chapterNo: 36, verseNo: 1))!]
              .ref,
        );
        await play('ayahs_away');
        expect(hifz().counts[HifzVerdict.skipped] ?? 0, 0);
        expect(hifz().counts[HifzVerdict.correct] ?? 0, greaterThan(20));
        final s9 = corpus.verseStartPosition((chapterNo: 36, verseNo: 9))!;
        expect(hifz().revealed, contains(corpus.words[s9].ref));
        // 36:1–36:8 shown (given), not tested.
        expect(hifz().revealed, contains(corpus.words[s9 - 1].ref));
        expect(hifz().marked[corpus.words[s9 - 1].ref], isNull);
      },
    );

    test('page visible: the reciter is looked for on that page only', () async {
      await setUpHifz(range: false);
      await play('wrong_page'); // Al-Kahf, with page 42 on screen
      expect(hifz().first, isNull);
      expect(hifz().counts[HifzVerdict.correct] ?? 0, 0);
    });
  });
}

int _argmax(Float32List logProbs, int frame, int classes) {
  var best = 0;
  for (var i = 1; i < classes; i++) {
    if (logProbs[frame * classes + i] > logProbs[frame * classes + best]) {
      best = i;
    }
  }
  return best;
}

/// Page lookups: none (the range's start page is not looked for).
class _NoPages implements QuranRepository {
  @override
  Future<int?> getPageForAyah({
    required int mushafId,
    required int ayahId,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
