/// Where Quran audio is streamed from (`docs/AUDIO_MILESTONE.md`): ayahs
/// from the Islamic Network CDN (everyayah.com for a reciter it has only
/// whole surahs of), words from the Quran.com CDN. Kept only when the
/// reader downloads a reciter.
library;

import '../../../quran/domain/quran_ayah_numbers.dart';

export '../../../quran/domain/quran_ayah_numbers.dart'
    show surahAyahCounts, globalAyahNumber, ayahIdAtGlobal;

/// A reciter offered for listening: an Islamic Network audio edition, or
/// an everyayah.com folder ([everyAyah]).
class Reciter {
  const Reciter(
    this.edition,
    this.nameEn,
    this.nameAr,
    this.kbps, {
    this.everyAyah,
  });

  /// The CDN edition, e.g. `ar.alafasy` — the reciter's id in the app
  /// (its setting, its downloads' folder) whatever serves it.
  final String edition;

  /// The everyayah.com folder serving its ayahs, for a reciter the
  /// Islamic Network has only whole surahs of.
  final String? everyAyah;
  final String nameEn, nameAr;

  /// The bitrate its ayah files are served at.
  final int kbps;
}

/// Ḥafṣ reciters, each checked to serve every ayah at [Reciter.kbps]
/// (2026-10-09) — 64 kbps wherever the CDN has it (2026-10-10: half the
/// size of 128, a difference hardly heard in recitation). A reciter who asks to be removed is removed here.
const reciters = [
  Reciter('ar.alafasy', 'Mishary Alafasy', 'مشاري العفاسي', 64),
  Reciter('ar.husary', 'Mahmoud Khalil Al-Husary', 'محمود خليل الحصري', 64),
  Reciter('ar.husarymujawwad', 'Al-Husary (Mujawwad)', 'الحصري (مجوّد)', 64),
  Reciter(
    'ar.minshawi',
    'Muhammad Siddiq Al-Minshawi',
    'محمد صديق المنشاوي',
    128,
  ),
  // (Not 'ar.minshawimujawwad': the CDN's ayah files for it are the
  // murattal recitation's, byte for byte — checked 2026-10-10.)
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
  Reciter('ar.mahermuaiqly', 'Maher Al-Muaiqly', 'ماهر المعيقلي', 64),
  Reciter('ar.hudhaify', 'Ali Al-Hudhaify', 'علي الحذيفي', 64),
  Reciter('ar.muhammadayyoub', 'Muhammad Ayyoub', 'محمد أيوب', 128),
  Reciter('ar.shaatree', 'Abu Bakr Ash-Shatri', 'أبو بكر الشاطري', 64),
  Reciter('ar.abdullahbasfar', 'Abdullah Basfar', 'عبد الله بصفر', 64),
  Reciter('ar.ahmedajamy', 'Ahmad al-Ajamy', 'أحمد بن علي العجمي', 64),
  Reciter('ar.hanirifai', 'Hani ar-Rifai', 'هاني الرفاعي', 64),
  Reciter('ar.aymanswoaid', 'Ayman Suwaid', 'أيمن سويد', 64),
  Reciter('ar.parhizgar', 'Shahriar Parhizgar', 'شهريار پرهيزگار', 48),
  Reciter('ar.muhammadjibreel', 'Muhammad Jibreel', 'محمد جبريل', 128),
  // The Islamic Network has him by whole surahs only (ar.mohamedtablawi);
  // everyayah.com by ayah — every ayah checked there, 2026-10-29.
  Reciter(
    'ar.tablawi',
    'Mohamed Al-Tablawi',
    'محمد محمود الطبلاوي',
    64,
    everyAyah: 'Mohammad_al_Tablaway_64kbps',
  ),
];

const defaultReciter = 'ar.alafasy';

Reciter reciterFor(String edition) => reciters.firstWhere(
  (r) => r.edition == edition,
  orElse: () => reciters.first,
);

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

String ayahAudioUrl(int ayahId, Reciter reciter) {
  final folder = reciter.everyAyah;
  if (folder != null) {
    String three(int n) => n.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/'
        '${three(ayahId ~/ 1000)}${three(ayahId % 1000)}.mp3';
  }
  return 'https://cdn.islamic.network/quran/audio/${reciter.kbps}/'
      '${reciter.edition}/${globalAyahNumber(ayahId)}.mp3';
}

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

/// Each reciter's whole recitation (all 6,236 ayah files), in bytes,
/// estimated (2026-10-10) from 250 sampled ayah files' sizes, fitted to the
/// ayahs' letter counts (within a few percent).
const reciterDownloadBytes = <String, int>{
  'ar.alafasy': 877486397,
  'ar.husary': 1245395110,
  'ar.husarymujawwad': 1795656526,
  'ar.minshawi': 1658509149,
  'ar.abdulbasitmurattal': 899447010,
  'ar.abdurrahmaansudais': 607405161,
  'ar.saoodshuraym': 1054243682,
  'ar.mahermuaiqly': 614719058,
  'ar.hudhaify': 876030953,
  'ar.muhammadayyoub': 937553634,
  'ar.shaatree': 743749929,
  'ar.abdullahbasfar': 850391972,
  'ar.ahmedajamy': 771903997,
  'ar.hanirifai': 733551083,
  'ar.aymanswoaid': 1194287490,
  'ar.parhizgar': 591531925,
  'ar.muhammadjibreel': 750775826,
  // Every file's size summed (2026-10-29).
  'ar.tablawi': 854317956,
};

/// [reciter]'s download size, as "≈ 640 MB" / "≈ 1.2 GB"; `null` if
/// unknown.
String? reciterDownloadSize(Reciter reciter) {
  final bytes = reciterDownloadBytes[reciter.edition];
  return bytes == null ? null : _sizeLabel(bytes.toDouble());
}

String _sizeLabel(double bytes) {
  final mb = bytes / (1000 * 1000);
  return mb >= 1000
      ? '≈ ${(mb / 1000).toStringAsFixed(1)} GB'
      : '≈ ${mb.round()} MB';
}

/// Each juz's first ayah, as a global ayah number (1–6236), juz 1 first.
const juzFirstAyah = <int>[
  1,
  149,
  260,
  386,
  517,
  641,
  751,
  900,
  1042,
  1201,
  1328,
  1479,
  1649,
  1803,
  2030,
  2215,
  2484,
  2674,
  2876,
  3215,
  3386,
  3564,
  3733,
  4090,
  4265,
  4511,
  4706,
  5105,
  5242,
  5673,
];

/// Each juz's share of the whole recitation (by its letters), juz 1 first
/// — for its download size.
const juzShare = <double>[
  0.0328,
  0.0339,
  0.0334,
  0.0329,
  0.0339,
  0.0331,
  0.0353,
  0.0332,
  0.0330,
  0.0322,
  0.0338,
  0.0334,
  0.0330,
  0.0323,
  0.0344,
  0.0338,
  0.0313,
  0.0344,
  0.0339,
  0.0324,
  0.0332,
  0.0338,
  0.0339,
  0.0323,
  0.0339,
  0.0342,
  0.0335,
  0.0347,
  0.0342,
  0.0298,
];

/// Juz [juz]'s ayahs, as global ayah numbers.
Iterable<int> juzAyahNumbers(int juz) sync* {
  final end = juz < 30 ? juzFirstAyah[juz] : 6237;
  for (var n = juzFirstAyah[juz - 1]; n < end; n++) {
    yield n;
  }
}

/// Juz [juz]'s download size for [reciter], as "≈ 30 MB"; `null` if
/// unknown.
String? juzDownloadSize(Reciter reciter, int juz) {
  final bytes = reciterDownloadBytes[reciter.edition];
  return bytes == null ? null : _sizeLabel(bytes * juzShare[juz - 1]);
}
