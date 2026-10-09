/// Where Quran audio is streamed from (`docs/AUDIO_MILESTONE.md`): ayahs
/// from the Islamic Network CDN, words from the Quran.com CDN. Nothing is
/// downloaded or kept.
library;

/// A reciter offered for listening: an Islamic Network audio edition.
class Reciter {
  const Reciter(this.edition, this.nameEn, this.nameAr, this.kbps);

  /// The CDN edition, e.g. `ar.alafasy`.
  final String edition;
  final String nameEn, nameAr;

  /// The bitrate its ayah files are served at.
  final int kbps;
}

/// Ḥafṣ reciters, each checked to serve every ayah at [Reciter.kbps]
/// (2026-10-09). A reciter who asks to be removed is removed here.
const reciters = [
  Reciter('ar.alafasy', 'Mishary Alafasy', 'مشاري العفاسي', 128),
  Reciter('ar.husary', 'Mahmoud Khalil Al-Husary', 'محمود خليل الحصري', 128),
  Reciter('ar.husarymujawwad', 'Al-Husary (Mujawwad)', 'الحصري (مجوّد)', 128),
  Reciter(
    'ar.minshawi',
    'Muhammad Siddiq Al-Minshawi',
    'محمد صديق المنشاوي',
    128,
  ),
  Reciter(
    'ar.minshawimujawwad',
    'Al-Minshawi (Mujawwad)',
    'المنشاوي (مجوّد)',
    64,
  ),
  Reciter(
    'ar.abdulbasitmurattal',
    'Abdul Basit Abdus-Samad',
    'عبد الباسط عبد الصمد',
    64,
  ),
  Reciter(
    'ar.abdurrahmaansudais',
    'Abdur-Rahman As-Sudais',
    'عبد الرحمن السديس',
    64,
  ),
  Reciter('ar.saoodshuraym', 'Saud Ash-Shuraym', 'سعود الشريم', 64),
  Reciter('ar.mahermuaiqly', 'Maher Al-Muaiqly', 'ماهر المعيقلي', 128),
  Reciter('ar.hudhaify', 'Ali Al-Hudhaify', 'علي الحذيفي', 128),
  Reciter('ar.muhammadayyoub', 'Muhammad Ayyoub', 'محمد أيوب', 128),
  Reciter('ar.shaatree', 'Abu Bakr Ash-Shatri', 'أبو بكر الشاطري', 128),
  Reciter('ar.abdullahbasfar', 'Abdullah Basfar', 'عبد الله بصفر', 64),
];

const defaultReciter = 'ar.alafasy';

Reciter reciterFor(String edition) => reciters.firstWhere(
  (r) => r.edition == edition,
  orElse: () => reciters.first,
);

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

/// [from] through [to] (stable ids), across surah ends; empty when [to]
/// comes first.
List<int> ayahRange(int from, int to) {
  final out = <int>[];
  var surah = from ~/ 1000, verse = from % 1000;
  while (surah <= 114 && surah * 1000 + verse <= to) {
    out.add(surah * 1000 + verse);
    if (verse < surahAyahCounts[surah - 1]) {
      verse++;
    } else {
      surah++;
      verse = 1;
    }
  }
  return out;
}

String ayahAudioUrl(int ayahId, Reciter reciter) =>
    'https://cdn.islamic.network/quran/audio/${reciter.kbps}/'
    '${reciter.edition}/${globalAyahNumber(ayahId)}.mp3';

/// Where Quran.com writes two canonical words as one (e.g. "بَعْدَ مَا"):
/// ayah id → index of the first of the pair (from the word-meaning
/// alignment, `tool/quran_data/src/qurancom_wbw_source.dart`).
const _joinedPairs = {2181: 2, 8006: 3, 13037: 7, 37130: 2};

/// Quran.com's 1-based position of canonical word [wordIndex] (0-based):
/// one less after a joined pair, the pair sharing one.
int quranComWordPosition(int ayahId, int wordIndex) {
  final joined = _joinedPairs[ayahId];
  if (joined == null || wordIndex <= joined) return wordIndex + 1;
  return wordIndex;
}

String wordAudioUrl(int ayahId, int wordIndex) {
  String three(int n) => n.toString().padLeft(3, '0');
  return 'https://audio.qurancdn.com/wbw/${three(ayahId ~/ 1000)}_'
      '${three(ayahId % 1000)}_${three(quranComWordPosition(ayahId, wordIndex))}.mp3';
}
