import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';

import '../matching/corpus_fixture.dart';
import 'acoustic_test_support.dart';

void main() {
  final corpus = loadTestCorpus();
  final reference = loadTestReference();
  const verifier = QuranAcousticVerifier();
  final cases =
      ((jsonDecode(
                File('test/fixtures/acoustic/alafasy_minimal_pairs.json')
                    .readAsStringSync(),
              ) as Map)['cases']
              as List)
          .cast<Map<String, Object?>>();
  // 68:38 words 1–5 «إِنَّ لَكُمْ فِيهِ لَمَا تَخَيَّرُونَ», «لَمَا» said «لِمَا».
  final c = cases.firstWhere((c) => c['name'] == 'vowel_FATHA_KASRA_0_spliced');
  final bytes = base64Decode(c['logProbs']! as String);
  final frames = AcousticFrames(
    frames: c['frames']! as int,
    classes: 43,
    logProbs: Float32List.view(bytes.buffer, bytes.offsetInBytes),
    frameDuration: const Duration(milliseconds: 40),
  );

  List<({int ayahId, int wordIndex})> words(int fromAyah, int toAyah) {
    final a = corpus.positionOf((ayahId: fromAyah, wordIndex: 0))!;
    final z = corpus.positionOf((ayahId: toAyah + 1, wordIndex: 0))! - 1;
    return [for (var p = a; p <= z; p++) corpus.words[p].ref];
  }

  test('an utterance is found among the words around it, across ayahs', () {
    final span = reference.span(words(68037, 68039));
    final (lo, hi) = verifier.locate(frames, span.tokens)!;
    final found = {
      for (final t in span.tokens)
        if (t.unit >= lo && t.unit <= hi) t.word,
    };
    expect(found, {for (var i = 0; i < 5; i++) (ayahId: 68038, wordIndex: i)});

    // …and verified there: the vowel of «لَمَا» is wrong, the rest right.
    final expected = [
      for (final t in span.tokens)
        if (t.unit >= lo && t.unit <= hi) t,
    ];
    final verdicts = verifier.verify(
      frames,
      expected,
      pauses: {
        for (final MapEntry(:key, :value) in span.pauses.entries)
          if (key >= lo && key <= hi) key: value,
      },
      openStart: true,
      openEnd: true,
    );
    final errors = verifier.errors(verdicts, frames.frameDuration);
    final mistakes = errors.where((e) => e.type.isError).toList();
    expect(mistakes.single.word, (ayahId: 68038, wordIndex: 3));
    expect(mistakes.single.type, RecitationErrorType.wrongVowel);
    expect(mistakes.single.observed, 'KASRA');
  });

  test('audio of other words is not placed among unrelated ones', () {
    final span = reference.span(words(2255, 2255));
    expect(verifier.locate(frames, span.tokens), isNull);
  });
}
