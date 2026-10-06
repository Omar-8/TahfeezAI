import 'dart:typed_data';

/// Frame-level acoustic evidence: for each audio frame, the
/// log-probability of every token in the model's vocabulary.
class AcousticFrames {
  AcousticFrames({
    required this.frames,
    required this.classes,
    required this.logProbs,
    required this.frameDuration,
  }) : assert(logProbs.length == frames * classes);

  final int frames;
  final int classes;

  /// Row-major `frames × classes` log-probabilities (CTC; class 0 blank).
  final Float32List logProbs;
  final Duration frameDuration;

  double at(int frame, int token) => logProbs[frame * classes + token];

  /// Frames [from]..[to] (inclusive) as their own [AcousticFrames].
  AcousticFrames slice(int from, int to) => AcousticFrames(
    frames: to - from + 1,
    classes: classes,
    logProbs: Float32List.sublistView(
      logProbs,
      from * classes,
      (to + 1) * classes,
    ),
    frameDuration: frameDuration,
  );
}

/// What a model hears and how it must be fed.
class AcousticModelInfo {
  const AcousticModelInfo({
    required this.id,
    required this.vocabulary,
    this.sampleRate = 16000,
    this.frameDuration = const Duration(milliseconds: 40),
  });

  final String id;

  /// Token symbols in class order; index 0 is the CTC blank. Symbols are
  /// Quran Phonetic Script characters.
  final List<String> vocabulary;

  /// Mono PCM sample rate the model takes.
  final int sampleRate;
  final Duration frameDuration;
}

/// A CTC acoustic model of Quran recitation: raw audio in, frame-level
/// token probabilities out — the acoustic evidence the verifier aligns
/// against the expected pronunciation. Tahfeez depends only on this
/// interface, so the model (and its runtime) can be swapped.
abstract interface class QuranAcousticModel {
  AcousticModelInfo get info;

  /// Mono samples in [-1, 1] at [AcousticModelInfo.sampleRate].
  Future<AcousticFrames> run(Float32List samples);

  Future<void> dispose();
}

/// [samples] through [model] in pieces it can take ([piece] long,
/// overlapping by [overlap]; each keeps its middle, so every frame had
/// context on both sides), as one block of frames — for audio longer than
/// one run allows (the model's memory grows with the square of the length).
Future<AcousticFrames> runInPieces(
  QuranAcousticModel model,
  Float32List samples, {
  int piece = 20 * 16000,
  int overlap = 2 * 16000,
  int samplesPerFrame = 640,
}) async {
  if (samples.length <= piece) return model.run(samples);
  final half = overlap ~/ 2 ~/ samplesPerFrame;
  final parts = <AcousticFrames>[];
  for (var start = 0; ; start += piece - overlap) {
    final end = start + piece < samples.length ? start + piece : samples.length;
    final f = await model.run(Float32List.sublistView(samples, start, end));
    final last = end == samples.length;
    parts.add(
      f.slice(start == 0 ? 0 : half, last ? f.frames - 1 : f.frames - half - 1),
    );
    if (last) break;
  }
  final classes = parts.first.classes;
  final total = parts.fold(0, (n, p) => n + p.frames);
  final out = Float32List(total * classes);
  var at = 0;
  for (final p in parts) {
    out.setAll(at, p.logProbs);
    at += p.logProbs.length;
  }
  return AcousticFrames(
    frames: total,
    classes: classes,
    logProbs: out,
    frameDuration: parts.first.frameDuration,
  );
}
