// On-device benchmark of the offline recitation pipeline (Milestone: Fully
// Offline Recitation Architecture). Needs no network: the model and a
// recitation are sideloaded into the app's external files directory
// (docs/ARCHITECTURE.md §32):
//
//   <files>/models/quran_acoustic.onnx + quran_acoustic.json
//   <files>/models/bench.pcm            (16 kHz mono PCM16LE)
//
// The recitation is streamed at real-time pace through exactly what the app
// runs — PcmRing, AcousticWindowing, LocalQuranAcousticModel, the frame
// store, LocalQuranPositionTracker — and every measurement is printed.
//
//   flutter test integration_test/acoustic_model_android_test.dart -d <id> \
//     --dart-define=ACOUSTIC_PROVIDER=cpu|xnnpack|nnapi \
//     [--dart-define=ACOUSTIC_THREADS=4] [--dart-define=ACOUSTIC_MINUTES=10]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/local_quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/pcm_ring.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/ai/matching/local_quran_position_tracker.dart';
import 'package:tahfeez_ai/ai/matching/quran_phoneme_index.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/ai/matching/quran_word_corpus.dart';

const _provider = String.fromEnvironment(
  'ACOUSTIC_PROVIDER',
  defaultValue: 'cpu',
);
const _threads = int.fromEnvironment('ACOUSTIC_THREADS');

/// Keep reciting (the recitation looped) this long, for thermals/battery.
const _minutes = int.fromEnvironment('ACOUSTIC_MINUTES');

void _log(String line) => debugPrint('BENCH $line');

Future<QuranWordCorpus> _corpus() async {
  final data = jsonDecode(
    await rootBundle.loadString('assets/quran/quran_dataset.json'),
  ) as Map<String, Object?>;
  final verses = {
    for (final a in (data['ayahs']! as List).cast<Map<String, Object?>>())
      a['id']! as int: (
        chapterNo: a['chapterNo']! as int,
        verseNo: a['verseNo']! as int,
      ),
  };
  return QuranWordCorpus.fromWords([
    for (final w in (data['ayahWords']! as List).cast<Map<String, Object?>>())
      (
        ref: (ayahId: w['ayahId']! as int, wordIndex: w['wordIndex']! as int),
        verse: verses[w['ayahId']]!,
        text: w['text']! as String,
      ),
  ]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline recitation pipeline on this device', (_) async {
    final model = LocalQuranAcousticModel(
      provider: AcousticExecutionProvider.values.byName(_provider),
      threads: _threads,
    );
    try {
      final raw = await const MethodChannel(LocalQuranAcousticModel.channelName)
          .invokeMethod<Object?>('status');
      _log('${DateTime.now()} raw status ok: ${'$raw'.length} chars');
    } catch (e) {
      _log('${DateTime.now()} raw status failed: $e');
    }
    final status = await model.status();
    _log('model: $status');
    expect(status.usable, isTrue, reason: '$status');
    final before = await model.deviceStats();
    _log(
      'before: cores ${before?.cores}, pss ${before?.pssKb} kB, battery '
      '${before?.batteryPercent}% ${before?.batteryCelsius} °C',
    );
    final load = await model.load();
    final loaded = await model.deviceStats();
    _log(
      'load: provider ${load.provider.name}, threads $_threads, '
      '${load.loadTime.inMilliseconds} ms (hash ${load.hashTime?.inMilliseconds} '
      'ms, session ${load.sessionTime?.inMilliseconds} ms), pss after load '
      '${loaded?.pssKb} kB',
    );

    // Resources, as the app builds them (timed: they are part of start-up).
    final resourcesWatch = Stopwatch()..start();
    final corpus = await _corpus();
    final reference = QuranPhoneticReference.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/quran/recitation/phonetic_reference_hafs.json',
        ),
      ) as Map<String, Object?>,
    );
    final ayahs = <(int, int)>[
      for (var p = 0; p < corpus.length; p++)
        if (corpus.words[p].ref.wordIndex == 0) (corpus.words[p].ref.ayahId, p),
    ];
    final index = QuranPhonemeIndex.build(reference, ayahs);
    _log(
      'resources: corpus + reference + index ${resourcesWatch.elapsedMilliseconds} ms',
    );

    // One warm 4 s window (the steady-state window: 2 s new + 1 s each side).
    for (final seconds in [4, 4, 8]) {
      final t = Stopwatch()..start();
      await model.run(Float32List(seconds * 16000));
      _log('single ${seconds}s window: ${t.elapsedMilliseconds} ms');
    }

    final dir = await getExternalStorageDirectory();
    final pcm = await File('${dir!.path}/models/bench.pcm').readAsBytes();
    final total = pcm.length ~/ 2;
    _log('audio: ${(total / 16000).toStringAsFixed(1)} s');

    // The app's windowing unless overridden (ACOUSTIC_HOP_MS / ACOUSTIC_CONTEXT_MS).
    const windowing = AcousticWindowing(
      minHop: Duration(
        milliseconds: int.fromEnvironment(
          'ACOUSTIC_HOP_MS',
          defaultValue: 1000,
        ),
      ),
      maxHop: Duration(seconds: 4),
      context: Duration(
        milliseconds: int.fromEnvironment(
          'ACOUSTIC_CONTEXT_MS',
          defaultValue: 500,
        ),
      ),
    );
    final runs = <int>[];
    final followLags = <int>[];
    var maxLag = 0, peakPss = loaded?.pssKb ?? 0, placedWords = 0;
    final placed = <String>[];
    int? locateMs;
    var trackerMicros = 0;
    final cpuStart = before?.cpuTime ?? Duration.zero;
    final wallStart = DateTime.now();
    final until = wallStart.add(Duration(minutes: _minutes));
    var pass = 0;

    do {
      pass++;
      final ring = PcmRing();
      final store = AcousticFrameStore(
        classes: 43,
        frameDuration: const Duration(milliseconds: 40),
      );
      final tracker = LocalQuranPositionTracker(
        corpus,
        () => (reference: reference, index: index),
      );
      // Ya-Sin's first page is on screen.
      final page = corpus.verseStartPosition((chapterNo: 36, verseNo: 1))!;
      tracker
        ..start(anchor: page)
        ..setFocus(page, page + 120);
      final started = DateTime.now();
      var fed = 0;
      int? firstSpeech;
      while (true) {
        // Audio arrives in real time.
        final now = DateTime.now().difference(started).inMicroseconds;
        final due = math.min(total, now * 16000 ~/ 1000000);
        if (due > fed) {
          ring.addPcm16(Uint8List.sublistView(pcm, fed * 2, due * 2));
          fed = due;
        }
        final flush = fed >= total;
        final window = windowing.next(
          written: ring.written,
          done: store.end,
          flush: flush,
          oldest: ring.oldest,
        );
        if (window == null) {
          if (flush) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        if (window.keepFrom > store.end) {
          // Fell more than the ring behind: that audio is skipped, as the
          // app's inference controller does (counted as dropped).
          final gap = window.keepFrom - store.end;
          _log('dropped ${gap * 40} ms of audio (too far behind)');
          final silence = Float32List(gap * 43);
          for (var f = 0; f < gap; f++) {
            for (var c = 1; c < 43; c++) {
              silence[f * 43 + c] = -30;
            }
          }
          store.add(
            TimedAcousticFrames(
              store.end,
              AcousticFrames(
                frames: gap,
                classes: 43,
                logProbs: silence,
                frameDuration: const Duration(milliseconds: 40),
              ),
            ),
          );
        }
        final t = Stopwatch()..start();
        final out = await model.run(ring.samples(window.from, window.to));
        runs.add(t.elapsedMilliseconds);
        _log(
          'window ${runs.length}: ${(window.to - window.from) / 16000} s '
          'audio in ${t.elapsedMilliseconds} ms, lag '
          '${(ring.written - window.keepTo * 640) * 1000 ~/ 16000} ms',
        );
        final offset = window.from ~/ 640;
        final kept = out.slice(
          window.keepFrom - offset,
          math.min(window.keepTo, offset + out.frames) - offset - 1,
        );
        final added = store.add(TimedAcousticFrames(window.keepFrom, kept));
        if (added == null) continue;
        final arrived = DateTime.now().difference(started).inMilliseconds;
        maxLag = math.max(maxLag, arrived - added.end * 40);
        firstSpeech ??= () {
          for (var f = 0; f < added.frames.frames; f++) {
            var best = 0;
            for (var c = 1; c < 43; c++) {
              if (added.frames.at(f, c) > added.frames.at(f, best)) best = c;
            }
            if (best != 0) return added.start + f;
          }
          return null;
        }();
        final tt = Stopwatch()..start();
        final events = [
          ...tracker.onFrames(added),
          if (flush) ...tracker.flush(),
        ];
        trackerMicros += tt.elapsedMicroseconds;
        final at = DateTime.now().difference(started).inMilliseconds;
        if (locateMs == null && events.any((e) => e is MatchRelocated)) {
          locateMs = at - (firstSpeech ?? 0) * 40;
        }
        final heard = events.whereType<WordHeard>().where((h) => h.ref != null);
        if (heard.isNotEmpty) {
          followLags.add(at - (tracker.lastPlacedFrame ?? 0) * 40);
          placedWords += heard.length;
          if (pass == 1) {
            placed.addAll(
              heard.map(
                (h) => '${h.ref!.ayahId % 1000}:${h.ref!.wordIndex + 1}',
              ),
            );
          }
        }
        final stats = await model.deviceStats();
        peakPss = math.max(peakPss, stats?.pssKb ?? 0);
      }
      final s = await model.deviceStats();
      _log(
        'pass $pass done at ${DateTime.now().difference(wallStart).inSeconds} s: '
        'battery ${s?.batteryPercent}% ${s?.batteryCelsius} °C '
        '${s?.batteryMicroAmps} µA, pss ${s?.pssKb} kB',
      );
    } while (DateTime.now().isBefore(until));

    final after = await model.deviceStats();
    final wall = DateTime.now().difference(wallStart);
    final audioSeconds = pass * total / 16000;
    final modelSeconds = runs.fold(0, (a, b) => a + b) / 1000;
    runs.sort();
    followLags.sort();
    int pct(List<int> v, double p) =>
        v.isEmpty ? -1 : v[((v.length - 1) * p).round()];
    _log('first pass placed: ${placed.join(' ')}');
    _log(
      'windows ${runs.length}: run median ${pct(runs, 0.5)} ms, p90 '
      '${pct(runs, 0.9)} ms, max ${runs.isEmpty ? -1 : runs.last} ms; RTF '
      '${(modelSeconds / audioSeconds).toStringAsFixed(2)}; max lag $maxLag ms',
    );
    _log(
      'locate ${locateMs ?? -1} ms after first speech; follow (word end → '
      'placed) median ${pct(followLags, 0.5)} ms, p90 ${pct(followLags, 0.9)} '
      'ms; words placed $placedWords; tracker '
      '${(trackerMicros / 1000 / math.max(1, runs.length)).toStringAsFixed(1)} '
      'ms per chunk',
    );
    final cpu = (after?.cpuTime ?? Duration.zero) - cpuStart;
    _log(
      'cpu ${(cpu.inMilliseconds / wall.inMilliseconds * 100).round()}% of one '
      'core over ${wall.inSeconds} s (${after?.cores} cores); peak pss '
      '$peakPss kB; battery ${before?.batteryPercent}% → '
      '${after?.batteryPercent}%, ${before?.batteryCelsius} → '
      '${after?.batteryCelsius} °C',
    );
    expect(placedWords, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 90)));
}
