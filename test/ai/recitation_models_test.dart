import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/domain/recitation_models.dart';

void main() {
  test('RecitationContext has value equality', () {
    const a = RecitationContext(
      chapterNo: 2,
      fromVerseNo: 1,
      toVerseNo: 5,
      scriptCode: 'uthmani_hafs',
    );
    const b = RecitationContext(
      chapterNo: 2,
      fromVerseNo: 1,
      toVerseNo: 5,
      scriptCode: 'uthmani_hafs',
    );
    expect(a, b);
  });

  test('RecitationEvent union round-trips through pattern matching', () {
    const event = RecitationEvent.wordSkipped(wordIndex: 3);

    final description = switch (event) {
      RecitationStarted() => 'started',
      RecitationPositionCandidate() => 'positionCandidate',
      RecitationAyahDetected() => 'ayahDetected',
      RecitationWordMatched() => 'wordMatched',
      RecitationWordSkipped(:final wordIndex) => 'wordSkipped:$wordIndex',
      RecitationWordIncorrect() => 'wordIncorrect',
      RecitationHesitation() => 'hesitation',
      RecitationSelfCorrection() => 'selfCorrection',
      RecitationConfidenceUpdate() => 'confidenceUpdate',
      RecitationEnded() => 'ended',
      RecitationRecognitionError() => 'recognitionError',
    };

    expect(description, 'wordSkipped:3');
  });
}
