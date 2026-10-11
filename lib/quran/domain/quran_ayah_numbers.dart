/// The Quran's ayah numbering: each surah's ayah count, and an ayah's
/// place in the whole Quran.
library;

/// Each surah's ayah count, in order — fixed Quran structure (it matches
/// the bundled dataset; `test/features/listen/quran_audio_sources_test.dart`).
const surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, //
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, //
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, //
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, //
  44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, //
  26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, //
  6, 3, 5, 4, 5, 6,
];

/// The ayah's number in the whole Quran (1–6236), from its stable id.
int globalAyahNumber(int ayahId) {
  final surah = ayahId ~/ 1000;
  var n = ayahId % 1000;
  for (var s = 1; s < surah; s++) {
    n += surahAyahCounts[s - 1];
  }
  return n;
}

/// The total number of ayahs.
const ayahTotal = 6236;

/// The stable id (`surah * 1000 + ayah`) of the [global]th ayah (1–6236).
int ayahIdAtGlobal(int global) {
  var n = global;
  for (var s = 1; s <= surahAyahCounts.length; s++) {
    final count = surahAyahCounts[s - 1];
    if (n <= count) return s * 1000 + n;
    n -= count;
  }
  return 114006;
}
