// On-device check of the Android live recognizer (Milestone R2).
//
// Feeds a real recitation, at real-time pace, through the same
// AndroidSpeechLiveRecognizer + RecognitionLatencyTracker the app uses and
// prints every event with its timing. The audio is not bundled: serve a
// 16 kHz mono PCM16LE file from the host and forward the port, e.g.
//
//   python3 -m http.server 8765 --directory <dir with clip.pcm>
//   adb reverse tcp:8765 tcp:8765
//   flutter test integration_test/live_recognition_android_test.dart \
//     -d <device> --dart-define=ASR_AUDIO_URL=http://127.0.0.1:8765/clip.pcm
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record/record.dart';
import 'package:tahfeez_ai/ai/speech/android_speech_live_recognizer.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/ai/speech/recognition_latency_tracker.dart';

const _audioUrl = String.fromEnvironment('ASR_AUDIO_URL');
const _onDevice = bool.fromEnvironment('ASR_ON_DEVICE');

Future<Uint8List> _download(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return builder.takeBytes();
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android recognizer transcribes live Arabic recitation', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The recognizer needs RECORD_AUDIO even when fed audio. Grant it from
      // the host (`adb shell pm grant <app> android.permission.RECORD_AUDIO`)
      // — this waits for that instead of showing a dialog.
      final recorder = AudioRecorder();
      for (var i = 0; i < 120; i++) {
        if (await recorder.hasPermission(request: false)) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await recorder.dispose();

      final recognizer = AndroidSpeechLiveRecognizer(preferOnDevice: _onDevice);
      final availability = await recognizer.checkAvailability();
      debugPrint(
        'ASR availability: ${availability.available} ${availability.detail}',
      );
      expect(availability.available, isTrue);
      if (_audioUrl.isEmpty) {
        markTestSkipped('No ASR_AUDIO_URL given');
        return;
      }
      final pcm = await _download(_audioUrl);
      debugPrint('ASR audio: ${pcm.length} bytes');

      final tracker = RecognitionLatencyTracker();
      final started = DateTime.now();
      String t() =>
          '+${DateTime.now().difference(started).inMilliseconds}ms'.padLeft(9);
      final partials = <String>[];
      final finals = <String>[];
      final firstPartialLatencies = <int>[];
      final finalLatencies = <int>[];

      final sub = recognizer.events.listen((event) {
        final now = DateTime.now();
        switch (event) {
          case LivePartialTranscript(:final text):
            partials.add(text);
            final l = tracker.onPartial(now);
            if (l != null) firstPartialLatencies.add(l.inMilliseconds);
            debugPrint(
              '${t()} partial: $text'
              '${l == null ? '' : '   [first-partial ${l.inMilliseconds} ms]'}',
            );
          case LiveFinalTranscript(:final text, :final confidence):
            finals.add(text);
            final l = tracker.onFinal(now);
            if (l != null) finalLatencies.add(l.inMilliseconds);
            debugPrint(
              '${t()} FINAL: $text (conf $confidence)'
              '${l == null ? '' : '   [final ${l.inMilliseconds} ms]'}',
            );
          case LiveRecognizerStatusChanged(:final status, :final detail):
            debugPrint('${t()} status: ${status.name} $detail');
          case LiveRecognitionError(:final message, :final recoverable):
            debugPrint('${t()} error: $message (recoverable $recoverable)');
        }
      });

      // 100 ms chunks, released on a real-time schedule like a microphone.
      final audio = StreamController<Uint8List>();
      await recognizer.start(
        LiveAudioInput(sampleRate: 16000, channels: 1, audio: audio.stream),
      );
      const chunkBytes = 3200;
      final clock = Stopwatch()..start();
      for (
        var offset = 0, i = 0;
        offset < pcm.length;
        offset += chunkBytes, i++
      ) {
        final due = Duration(milliseconds: 100 * i);
        final wait = due - clock.elapsed;
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final chunk = Uint8List.sublistView(
          pcm,
          offset,
          (offset + chunkBytes).clamp(0, pcm.length),
        );
        tracker.onAudio(chunk, DateTime.now());
        audio.add(chunk);
      }
      debugPrint('${t()} audio finished, stopping');
      await recognizer.stop();
      await Future<void>.delayed(const Duration(seconds: 4));
      await sub.cancel();
      await audio.close();
      await recognizer.dispose();

      int? avg(List<int> xs) =>
          xs.isEmpty ? null : xs.reduce((a, b) => a + b) ~/ xs.length;
      debugPrint(
        'ASR SUMMARY partials=${partials.length} finals=${finals.length} '
        'firstPartial(ms)=$firstPartialLatencies avg=${avg(firstPartialLatencies)} '
        'final(ms)=$finalLatencies avg=${avg(finalLatencies)}',
      );
      debugPrint('ASR TRANSCRIPT: ${finals.join(' | ')}');
      expect(partials, isNotEmpty);
    });
  });
}
