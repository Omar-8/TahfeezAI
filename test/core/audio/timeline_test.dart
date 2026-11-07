import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/audio/just_audio_controller.dart';

void main() {
  test(
    'a run\'s lengths: as loaded, else measured (scaled), else the mean',
    () {
      // (The loaded one 25% over its measure: the measured one scaled alike.)
      expect(timelineLengths([5000, null, null], [4000, 3000, null]), [
        5000,
        3750,
        4375,
      ]);
      expect(timelineLengths([null, null], [null, null]), [10000, 10000]);
      // Loaded ones 10% longer than measured: the rest scaled alike.
      expect(timelineLengths([1100, null], [1000, 2000]), [1100, 2200]);
    },
  );

  test('a place on the run\'s timeline: its ayah and the place in it', () {
    const lengths = [5000, 3000, 4000];
    expect(timelinePlace(lengths, 0), (index: 0, offsetMs: 0));
    expect(timelinePlace(lengths, 6500), (index: 1, offsetMs: 1500));
    expect(timelinePlace(lengths, 8000), (index: 2, offsetMs: 0));
    expect(timelinePlace(lengths, 99000), (index: 2, offsetMs: 4000));
    expect(timelinePlace(const [], 10), isNull);
  });
}
