import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/ai/speech/recognition_latency_tracker.dart';
import 'package:tahfeez_ai/ai/speech/web_speech_result_tracker.dart';

/// 100 ms of 16 kHz mono PCM16: a 440 Hz tone at [amplitude] (0–1).
Uint8List chunk(double amplitude) {
  final data = ByteData(3200);
  for (var i = 0; i < 1600; i++) {
    final v = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / 16000))
        .round();
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('RecognitionLatencyTracker', () {
    final t0 = DateTime.utc(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('levelDb', () {
      expect(RecognitionLatencyTracker.levelDb(Uint8List(3200)), -96);
      // A full-scale sine is −3 dBFS RMS.
      expect(RecognitionLatencyTracker.levelDb(chunk(1)), closeTo(-3, 0.1));
    });

    test('first-partial latency is measured from voice onset', () {
      final tracker = RecognitionLatencyTracker();
      for (var i = 0; i < 10; i++) {
        tracker.onAudio(chunk(0.0005), at(i * 100));
      }
      expect(tracker.speaking, isFalse);
      tracker.onAudio(chunk(0.3), at(1000));
      expect(tracker.speaking, isTrue);
      tracker.onAudio(chunk(0.3), at(1100));

      expect(tracker.onPartial(at(1700)), const Duration(milliseconds: 700));
      // Only the first partial after onset counts.
      expect(tracker.onPartial(at(1800)), isNull);
    });

    test('final latency is measured from the end of voice', () {
      final tracker = RecognitionLatencyTracker();
      tracker.onAudio(chunk(0.0005), at(0));
      tracker.onAudio(chunk(0.3), at(100));
      tracker.onAudio(chunk(0.3), at(200));
      // Mid-speech finals have no end to measure from.
      expect(tracker.onFinal(at(250)), isNull);
      for (var ms = 300; ms <= 800; ms += 100) {
        tracker.onAudio(chunk(0.0005), at(ms));
      }
      expect(tracker.speaking, isFalse);
      expect(tracker.onFinal(at(1100)), const Duration(milliseconds: 900));
    });

    test('a new utterance after a pause re-arms first-partial timing', () {
      final tracker = RecognitionLatencyTracker();
      tracker.onAudio(chunk(0.3), at(0));
      tracker.onPartial(at(300));
      for (var ms = 100; ms <= 600; ms += 100) {
        tracker.onAudio(chunk(0.0005), at(ms));
      }
      tracker.onAudio(chunk(0.3), at(2000));
      expect(tracker.onPartial(at(2400)), const Duration(milliseconds: 400));
    });
  });

  group('WebSpeechResultTracker', () {
    WebSpeechResult r(String text, {bool isFinal = false}) =>
        (isFinal: isFinal, transcript: text, confidence: isFinal ? 0.9 : 0);

    test('joins the non-final tail into one partial', () {
      final tracker = WebSpeechResultTracker();
      final events = tracker.onResult([r('الله لا'), r(' اله')], 0);
      expect(events.single, isA<LivePartialTranscript>());
      expect((events.single as LivePartialTranscript).text, 'الله لا اله');
    });

    test('emits each final once, even as the list keeps growing', () {
      final tracker = WebSpeechResultTracker();
      var events = tracker.onResult([
        r('الله لا اله الا هو', isFinal: true),
      ], 0);
      expect((events.single as LiveFinalTranscript).text, 'الله لا اله الا هو');

      events = tracker.onResult([
        r('الله لا اله الا هو', isFinal: true),
        r('الحي'),
      ], 0);
      expect(events.whereType<LiveFinalTranscript>(), isEmpty);
      expect((events.single as LivePartialTranscript).text, 'الحي');

      events = tracker.onResult([
        r('الله لا اله الا هو', isFinal: true),
        r('الحي القيوم', isFinal: true),
      ], 1);
      expect((events.single as LiveFinalTranscript).text, 'الحي القيوم');
    });

    test('reset starts a new browser session', () {
      final tracker = WebSpeechResultTracker();
      tracker.onResult([r('a', isFinal: true)], 0);
      tracker.reset();
      final events = tracker.onResult([r('b', isFinal: true)], 0);
      expect((events.single as LiveFinalTranscript).text, 'b');
    });
  });

  test('normalizeTranscriptSpacing only touches whitespace', () {
    expect(normalizeTranscriptSpacing(' الله  لا\tاله '), 'الله لا اله');
  });
}
