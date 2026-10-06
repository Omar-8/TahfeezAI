import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_frame_stream.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';

/// [n] frames of 2 classes whose first value is [first], [first]+1, ….
AcousticFrames numbered(int first, int n) {
  final lp = Float32List(n * 2);
  for (var i = 0; i < n; i++) {
    lp[i * 2] = (first + i).toDouble();
  }
  return AcousticFrames(
    frames: n,
    classes: 2,
    logProbs: lp,
    frameDuration: const Duration(milliseconds: 40),
  );
}

void main() {
  group('AcousticWindowing', () {
    const w = AcousticWindowing();
    const s = 16000;

    test('waits for 2 s of new audio plus 1 s of right context', () {
      expect(w.next(written: 3 * s - 1, done: 0), isNull);
      final first = w.next(written: 3 * s, done: 0)!;
      // The stream start has no left context; frames 0..50 are kept.
      expect(first, (from: 0, to: 3 * s, keepFrom: 0, keepTo: 50));
    });

    test('later windows carry 1 s of context on both sides', () {
      final next = w.next(written: 5 * s, done: 50)!;
      expect(next.from, 1 * s); // 50 frames = 2 s, minus 1 s context
      expect(next.to, 5 * s);
      expect(next.keepFrom, 50);
      expect(next.keepTo, 100);
      // Kept frames start 1 s (25 frames) into the window.
      expect(next.keepFrom - next.from ~/ 640, 25);
    });

    test('a device that falls behind runs longer windows, up to 6 s new', () {
      final behind = w.next(written: 20 * s, done: 50)!;
      expect(behind.keepTo - behind.keepFrom, 150); // 6 s
      expect(behind.to - behind.from, 8 * s); // + 1 s each side
    });

    test('a flush computes the tail at once, without right context', () {
      expect(w.next(written: 50 * 640 + 300, done: 50, flush: true), isNull);
      final tail = w.next(written: 60 * 640 + 300, done: 50, flush: true)!;
      expect(tail.keepFrom, 50);
      expect(tail.keepTo, 60);
      expect(tail.to, 60 * 640 + 300);
    });

    test('audio the ring no longer holds is skipped, not run', () {
      final late = w.next(written: 100 * s, done: 0, oldest: 10 * s + 5)!;
      expect(late.keepFrom, (10 * s + 5 + 639) ~/ 640);
      expect(late.from, greaterThanOrEqualTo(10 * s));
      expect(late.from % 640, 0);
    });
  });

  group('AcousticFrameStore', () {
    test('keeps only new frames from overlapping chunks', () {
      final store = AcousticFrameStore(
        classes: 2,
        frameDuration: const Duration(milliseconds: 40),
      );
      expect(store.add(TimedAcousticFrames(0, numbered(0, 10)))!.end, 10);
      final added = store.add(TimedAcousticFrames(5, numbered(5, 10)))!;
      expect((added.start, added.end), (10, 15));
      expect(added.frames.at(0, 0), 10);
      expect(store.add(TimedAcousticFrames(3, numbered(3, 4))), isNull);
      final all = store.slice(0, 15)!;
      for (var f = 0; f < 15; f++) {
        expect(all.frames.at(f, 0), f);
      }
    });

    test('refuses a gap, and drops frames past its capacity', () {
      final store = AcousticFrameStore(
        classes: 2,
        frameDuration: const Duration(milliseconds: 40),
        capacity: 20,
      );
      store.add(TimedAcousticFrames(0, numbered(0, 10)));
      expect(
        () => store.add(TimedAcousticFrames(12, numbered(12, 2))),
        throwsStateError,
      );
      store.add(TimedAcousticFrames(10, numbered(10, 25)));
      expect(store.start, 15);
      expect(store.slice(10, 20), isNull, reason: 'dropped');
      expect(store.slice(30, 40), isNull, reason: 'not computed yet');
      final kept = store.slice(15, 35)!;
      expect(kept.frames.at(0, 0), 15);
      expect(kept.frames.at(19, 0), 34);
    });
  });
}
