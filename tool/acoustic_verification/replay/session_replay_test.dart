// Replays recorded phone sessions through the app's whole on-device
// pipeline — the inference controller (its chunks and pauses), the position
// tracker, the Hifz test and the pronunciation checks — with the session's
// audio as the microphone and, as the model, the frames a stateful run of
// the streaming model computed over it offline (model_work/bench_run.py
// with STREAM_CFG, pack `sessions`). Writes each session's verdicts and the
// pipeline's log to model_work/artifacts/results/replay_<tag>/.
//
//   REPLAY_TAG=sessions_v34s flutter test \
//     tool/acoustic_verification/replay/session_replay_test.dart
//
// Recordings and results stay on this machine (artifacts/ is not in git).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_model_manifest.dart';
import 'package:tahfeez_ai/ai/acoustic/local_quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/screen_awake.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_position_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/local_acoustic_inference_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_ai_config.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/repositories/quran_repository.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../test/ai/acoustic/acoustic_test_support.dart';
import '../../../test/ai/acoustic/local_quran_acoustic_model_test.dart'
    show manifestJson;
import '../../../test/ai/matching/corpus_fixture.dart';
import '../../../test/ai/matching/position_fixture_support.dart';
import '../../../test/features/recitation/recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

const _art = 'tool/acoustic_verification/model_work/artifacts';

void main() {
  final tag = Platform.environment['REPLAY_TAG'] ?? 'sessions_v34s';
  final only = Platform.environment['REPLAY_ONLY'];
  final meta = (jsonDecode(
    File('$_art/results/$tag.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final bytes = File('$_art/results/$tag.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  final out = Directory('$_art/results/replay_$tag')..createSync();
  final corpus = loadTestCorpus();

  for (final m in meta) {
    final name = m['name']! as String;
    if (only != null && !name.contains(only)) continue;
    test(name, () async {
      final main = m['main']! as Map;
      final n = main['frames'] as int, off = main['offset'] as int;
      final frames = AcousticFrames(
        frames: n,
        classes: 43,
        logProbs: Float32List.sublistView(all, off, off + n * 43),
        frameDuration: const Duration(milliseconds: 40),
      );
      final log = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => log.add(message ?? '');
      addTearDown(() => debugPrint = print);

      final mic = FakeAudioSource();
      final model = _ReplayModel(frames);
      final container = ProviderContainer(
        overrides: [
          recitationAiConfigProvider.overrideWithValue(_offlineAndroid),
          recitationAudioSourceFactoryProvider.overrideWithValue(() => mic),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          localQuranAcousticModelProvider.overrideWithValue(model),
          screenAwakeProvider.overrideWithValue(_Awake()),
          quranWordCorpusProvider.overrideWith((ref) async => corpus),
          quranPhonemeResourcesProvider.overrideWith(
            (ref) async => loadTestPhonemes(),
          ),
          quranPhoneticReferenceProvider.overrideWith(
            (ref) async => loadTestReference(),
          ),
          browserStorageProvider.overrideWithValue(_MemoryStorage()),
          hifzHapticsProvider.overrideWithValue(() {}),
          hifzBeepProvider.overrideWithValue(() {}),
          quranRepositoryProvider.overrideWithValue(_NoPages()),
          memorizationRecordDelayProvider.overrideWithValue(Duration.zero),
          memorizationRecorderProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(mushafRecitationTargetProvider.notifier)
          .show('screen', const QuranLocation.page(1, 1));
      container.listen(liveRecognitionControllerProvider, (_, _) {});
      container.listen(hifzControllerProvider, (_, _) {});
      container.listen(acousticVerificationControllerProvider, (_, _) {});
      container.listen(localAcousticInferenceControllerProvider, (_, _) {});
      await container.read(quranWordCorpusProvider.future);
      await container.read(quranPhonemeResourcesProvider.future);
      await container.read(quranPhoneticReferenceProvider.future);
      final ayahs = (m['ayahs']! as List).cast<int>();
      int chapter(int a) => a ~/ 1000;
      int verse(int a) => a % 1000;
      container.read(hifzControllerProvider.notifier).setRange((
        from: (chapterNo: chapter(ayahs.first), verseNo: verse(ayahs.first)),
        to: (chapterNo: chapter(ayahs.last), verseNo: verse(ayahs.last)),
      ));
      final session = container.read(
        recitationSessionControllerProvider.notifier,
      );
      await session.start(startLocation: const QuranLocation.page(1, 1));
      await pumpEventQueue();

      // The recording, 0.1 s at a time.
      final pcm = _wavPcm(File(m['wav']! as String).readAsBytesSync());
      const step = 3200;
      for (var i = 0; i < pcm.length; i += step) {
        mic.mic!.add(
          Uint8List.sublistView(pcm, i, (i + step).clamp(0, pcm.length)),
        );
        await pumpEventQueue(times: 3);
      }
      session.pause();
      for (var i = 0; i < 400; i++) {
        await pumpEventQueue();
        if (container.read(acousticVerificationControllerProvider).pending ==
                0 &&
            i > 50) {
          break;
        }
      }
      final words = container
          .read(acousticVerificationControllerProvider)
          .words;
      final hifz = container.read(hifzControllerProvider);
      File('${out.path}/$name.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert({
          'session': name,
          'ayahs': ayahs,
          'counts': {for (final e in hifz.counts.entries) e.key.name: e.value},
          'words': [
            for (final MapEntry(key: w, value: r) in words.entries)
              {
                'word': '${w.ayahId}:${w.wordIndex}',
                'type': r.type.name,
                'provisional': r.provisional,
                'errors': [for (final e in r.errors) '$e'],
              },
          ],
        }),
      );
      File('${out.path}/$name.log').writeAsStringSync(log.join('\n'));
      await session.stop();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}

/// The session's audio as PCM16 (the WAV's data chunk).
Uint8List _wavPcm(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  var at = 12;
  while (at + 8 <= wav.length) {
    final id = String.fromCharCodes(wav.sublist(at, at + 4));
    final size = view.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      return Uint8List.sublistView(wav, at + 8, at + 8 + size);
    }
    at += 8 + size;
  }
  throw const FormatException('No data chunk');
}

/// The streaming model, replayed: each committed run hands out the next
/// frames of the offline stateful run (a run's whole 40 ms frames, as
/// stream_model.py computes them); a provisional run, the same frames
/// without moving on.
class _ReplayModel extends LocalQuranAcousticModel {
  _ReplayModel(this.frames);
  final AcousticFrames frames;
  var _cursor = 0;

  @override
  Future<LocalAcousticModelStatus> status() async => LocalAcousticModelStatus(
    LocalAcousticModelState.present,
    path: '/replay',
    manifest: AcousticModelManifest.fromJson(manifestJson()),
  );

  @override
  Future<AcousticModelLoad> load() async => const AcousticModelLoad(
    provider: AcousticExecutionProvider.cpu,
    loadTime: Duration.zero,
  );

  @override
  AcousticStreamConfig get stream => const AcousticStreamConfig(
    chunkSamples: 20480,
    overlapSamples: 240,
    chunkSeconds: 1.28,
    leftSeconds: 5.12,
  );

  @override
  Future<void> streamReset() async => _cursor = 0;

  @override
  Future<AcousticFrames> streamRun(
    Float32List samples, {
    bool commit = true,
  }) async {
    final tenMs = samples.length < 400 ? 0 : (samples.length - 400) ~/ 160 + 1;
    final k = (tenMs ~/ 4 * 4) ~/ 4;
    final from = _cursor.clamp(0, frames.frames);
    final to = (_cursor + k).clamp(from, frames.frames);
    if (commit) _cursor += k;
    if (to <= from) {
      return AcousticFrames(
        frames: 0,
        classes: 43,
        logProbs: Float32List(0),
        frameDuration: frames.frameDuration,
      );
    }
    return frames.slice(from, to - 1);
  }

  @override
  Future<AcousticFrames> run(Float32List samples) =>
      throw StateError('A streaming model is not run on pieces');
}

final _offlineAndroid = resolveRecitationAiConfig(
  backendName: '',
  positionName: '',
  comparator: false,
  offline: true,
  android: true,
  release: false,
);

class _Awake implements ScreenAwake {
  @override
  Future<void> keepOn(bool on) async {}
}

class _MemoryStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}

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

class _NoPages implements QuranRepository {
  @override
  Future<int?> getPageForAyah({
    required int mushafId,
    required int ayahId,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
