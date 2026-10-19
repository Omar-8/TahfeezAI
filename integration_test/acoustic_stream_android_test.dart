// On-device benchmark of a streaming acoustic model (v3.x): the sideloaded
// model and recitation, as for acoustic_model_android_test.dart
//
//   <files>/models/quran_acoustic.onnx + quran_acoustic.json
//   <files>/models/bench.pcm            (16 kHz mono PCM16LE)
//
// fed chunk by chunk (the manifest's chunk, its overlap after it) at
// real-time pace, the state carried on, as the app streams it. Printed: load
// time; per-chunk model time (median / p90 / max) against the chunk's length;
// CPU share; peak PSS; battery and temperature before and after.
//
//   flutter test integration_test/acoustic_stream_android_test.dart -d <id> \
//     [--dart-define=ACOUSTIC_MINUTES=5] [--dart-define=ACOUSTIC_THREADS=4]

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tahfeez_ai/ai/acoustic/local_quran_acoustic_model.dart';

const _minutes = int.fromEnvironment('ACOUSTIC_MINUTES', defaultValue: 3);

void _log(String line) => debugPrint('BENCH $line');

int _pct(List<int> sorted, double p) =>
    sorted[math.min(sorted.length - 1, (sorted.length * p).floor())];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('streaming model on this device', (_) async {
    final model = LocalQuranAcousticModel(
      threads: const int.fromEnvironment('ACOUSTIC_THREADS'),
    );
    // Installing the test app clears its files: the model may be pushed
    // only now — wait for it (and the recitation).
    var status = await model.status();
    for (var i = 0; i < 90 && !status.usable; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      status = await model.status();
    }
    final pcmFile = File(
      '${(await getExternalStorageDirectory())!.path}/models/bench.pcm',
    );
    for (var i = 0; i < 30 && !pcmFile.existsSync(); i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    _log('model: $status');
    expect(status.usable, isTrue, reason: '$status');
    final before = await model.deviceStats();
    _log(
      'before: cores ${before?.cores}, pss ${before?.pssKb} kB, battery '
      '${before?.batteryPercent}% ${before?.batteryCelsius} °C',
    );
    final load = await model.load();
    _log('load: ${load.loadTime.inMilliseconds} ms');
    final stream = model.stream;
    expect(stream, isNotNull, reason: 'not a streaming model');
    final chunk = stream!.chunkSamples, overlap = stream.overlapSamples;

    final pcm = await pcmFile.readAsBytes();
    final audio = Float32List(pcm.length ~/ 2);
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < audio.length; i++) {
      audio[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    _log(
      'audio: ${(audio.length / 16000).toStringAsFixed(1)} s, chunk '
      '${stream.chunkSeconds} s',
    );

    final runs = <int>[], cpu = <int>[];
    var peakPss = 0, maxLag = 0;
    final cpuStart = (await model.deviceStats())?.cpuTime ?? Duration.zero;
    final wallStart = DateTime.now();
    final until = wallStart.add(const Duration(minutes: _minutes));
    var passes = 0;
    while (DateTime.now().isBefore(until)) {
      passes++;
      await model.streamReset();
      final started = DateTime.now();
      for (var at = 0; at + chunk + overlap <= audio.length; at += chunk) {
        // The chunk is complete (with its overlap) only once heard.
        final due = Duration(
          microseconds: (at + chunk + overlap) * 1000000 ~/ 16000,
        );
        final wait = due - DateTime.now().difference(started);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        await model.streamRun(
          Float32List.sublistView(audio, at, at + chunk + overlap),
        );
        runs.add(model.lastRunTime!.inMilliseconds);
        cpu.add(model.lastCpuTime!.inMilliseconds);
        final lag = (DateTime.now().difference(started) - due).inMilliseconds;
        maxLag = math.max(maxLag, lag);
      }
      final stats = await model.deviceStats();
      peakPss = math.max(peakPss, stats?.pssKb ?? 0);
    }
    final after = await model.deviceStats();
    final wall = DateTime.now().difference(wallStart);
    final sorted = [...runs]..sort();
    final chunkMs = (stream.chunkSeconds * 1000).round();
    _log(
      'chunks: ${runs.length} in $passes passes; model ms median '
      '${_pct(sorted, 0.5)}, p90 ${_pct(sorted, 0.9)}, max ${sorted.last} '
      '(chunk $chunkMs ms: RTF ${(_pct(sorted, 0.5) / chunkMs).toStringAsFixed(2)}); '
      'max lag $maxLag ms',
    );
    final cpuUsed = (after?.cpuTime ?? Duration.zero) - cpuStart;
    _log(
      'cpu: ${(cpuUsed.inMilliseconds / wall.inMilliseconds * 100).toStringAsFixed(0)}% '
      'of one core over ${wall.inSeconds} s (model cpu ms median '
      '${(([...cpu]..sort())[cpu.length ~/ 2])}); peak pss $peakPss kB',
    );
    _log(
      'after: battery ${after?.batteryPercent}% ${after?.batteryCelsius} °C',
    );
    await model.dispose();
  });
}
