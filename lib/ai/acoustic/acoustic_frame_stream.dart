import 'dart:math' as math;
import 'dart:typed_data';

import 'quran_acoustic_model.dart';

/// Acoustic frames placed on the session's audio timeline: frame `i` of
/// [frames] is frame [start] `+ i` of the stream (frame `j` covers samples
/// `j * samplesPerFrame` up to the next frame).
class TimedAcousticFrames {
  const TimedAcousticFrames(this.start, this.frames, {this.last = false});

  final int start;
  final AcousticFrames frames;

  /// The audio paused or ended after these frames: nothing follows them
  /// until it resumes.
  final bool last;

  /// One past the last frame.
  int get end => start + frames.frames;
}

/// The stream's frames, kept for the last [capacity] frames: what the
/// position tracker followed and the verifier checks are the same frames,
/// computed once.
///
/// Windows overlap; [add] keeps only frames not stored yet (the first
/// window to reach a frame wins — its right context was trimmed, so it is
/// already final).
class AcousticFrameStore {
  AcousticFrameStore({
    required this.classes,
    required this.frameDuration,
    this.capacity = 2250, // 90 s at 40 ms
  }) : _data = Float32List(capacity * classes);

  final int classes;
  final Duration frameDuration;
  final int capacity;
  final Float32List _data;
  int _end = 0;

  /// One past the last frame stored.
  int get end => _end;

  /// The oldest frame still kept.
  int get start => math.max(0, _end - capacity);

  void reset() => _end = 0;

  /// Stores [chunk]'s new frames and returns them, or `null` if it holds
  /// none. A chunk may not leave a gap after [end].
  TimedAcousticFrames? add(TimedAcousticFrames chunk) {
    if (chunk.frames.classes != classes) {
      throw ArgumentError('Expected $classes classes');
    }
    if (chunk.start > _end) {
      throw StateError('Gap in frames: ${chunk.start} after $_end');
    }
    final from = _end;
    if (chunk.end <= from) return null;
    for (var f = from; f < chunk.end; f++) {
      final row = (f % capacity) * classes;
      final src = (f - chunk.start) * classes;
      _data.setRange(row, row + classes, chunk.frames.logProbs, src);
    }
    _end = chunk.end;
    return slice(from, _end);
  }

  /// Writes [chunk]'s frames, replacing any stored at the same positions
  /// (a streaming model's provisional tail, computed when the audio paused
  /// mid-chunk, replaced by the chunk's final frames). Returns the frames
  /// written. A chunk may not leave a gap after [end].
  TimedAcousticFrames put(TimedAcousticFrames chunk) {
    if (chunk.frames.classes != classes) {
      throw ArgumentError('Expected $classes classes');
    }
    if (chunk.start > _end) {
      throw StateError('Gap in frames: ${chunk.start} after $_end');
    }
    final from = math.max(chunk.start, start);
    for (var f = from; f < chunk.end; f++) {
      final row = (f % capacity) * classes;
      final src = (f - chunk.start) * classes;
      _data.setRange(row, row + classes, chunk.frames.logProbs, src);
    }
    _end = math.max(_end, chunk.end);
    return slice(from, chunk.end)!;
  }

  /// Frames [from]..[to] (exclusive) as one block, or `null` when any of
  /// them is not stored (not computed yet, or already dropped).
  TimedAcousticFrames? slice(int from, int to) {
    if (from < start || to > _end || to <= from) return null;
    final out = Float32List((to - from) * classes);
    for (var f = from; f < to; f++) {
      final row = (f % capacity) * classes;
      out.setRange((f - from) * classes, (f - from + 1) * classes, _data, row);
    }
    return TimedAcousticFrames(
      from,
      AcousticFrames(
        frames: to - from,
        classes: classes,
        logProbs: out,
        frameDuration: frameDuration,
      ),
    );
  }
}

/// One model run over the stream: samples [from]..[to] (exclusive), whose
/// frames [keepFrom]..[keepTo] (stream frame indices, exclusive) are kept.
typedef AcousticWindow = ({int from, int to, int keepFrom, int keepTo});

/// How the live stream is cut into model runs.
///
/// The model sees the whole window, but frames near a cut edge lack
/// context and differ from what the full recitation would give. So each
/// window carries [context] of audio on both sides, and only its middle is
/// kept. Measured with the Quran acoustic model on 40 s of continuous
/// recitation (`tool/acoustic_verification/model_work`, window probe):
/// frame agreement with one run over all 40 s was 90.8% with no context,
/// 92.3% with 0.5 s, 93.9% with 1 s, and no better with more (94.0–94.3%
/// for 1.5–2 s, or 6–8 s windows).
///
/// The windows are elastic: one runs as soon as [minHop] of new audio is
/// ready, covering up to [maxHop] of it, so a device that falls behind
/// catches up with longer windows (less overlap to recompute) instead of
/// falling further back.
class AcousticWindowing {
  const AcousticWindowing({
    this.minHop = const Duration(seconds: 2),
    this.maxHop = const Duration(seconds: 6),
    this.context = const Duration(seconds: 1),
    this.sampleRate = 16000,
    this.samplesPerFrame = 640,
  });

  final Duration minHop, maxHop, context;
  final int sampleRate, samplesPerFrame;

  int _samples(Duration d) =>
      (d.inMicroseconds * sampleRate / 1e6).round() ~/
      samplesPerFrame *
      samplesPerFrame;

  /// The next window, given the [written] samples and the frames [done]
  /// (all before it are computed), or `null` if not enough new audio.
  /// [flush]: the audio has paused or ended, so its tail is computed now,
  /// without right context. [oldest]: the first sample still available.
  AcousticWindow? next({
    required int written,
    required int done,
    bool flush = false,
    int oldest = 0,
  }) {
    final ctx = _samples(context);
    // The audio before [oldest] is gone: skip the frames it held.
    final first = math.max(
      done,
      (oldest + samplesPerFrame - 1) ~/ samplesPerFrame,
    );
    final keepStart = first * samplesPerFrame;
    final available = written - keepStart - (flush ? 0 : ctx);
    if (available < (flush ? samplesPerFrame : _samples(minHop))) return null;
    final int keepEnd = keepStart + math.min(available, _samples(maxHop));
    final oldestFrame = first == done ? oldest : keepStart;
    final int from = math.max(math.max(0, keepStart - ctx), oldestFrame);
    final int to = math.min(written, keepEnd + ctx);
    return (
      // Whole frames from the start of the window.
      from: keepStart - (keepStart - from) ~/ samplesPerFrame * samplesPerFrame,
      to: to,
      keepFrom: first,
      keepTo: keepEnd ~/ samplesPerFrame,
    );
  }
}
