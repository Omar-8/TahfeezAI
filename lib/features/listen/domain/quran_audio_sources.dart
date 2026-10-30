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
  // Likewise (ar.mahmoudalialbanna by whole surahs); everyayah.com has
  // him at 32 kbps only (mono) — every ayah checked there, 2026-10-30.
  Reciter(
    'ar.banna',
    'Mahmoud Ali Al-Banna',
    'محمود علي البنا',
    32,
    everyAyah: 'mahmoud_ali_al_banna_32kbps',
  ),
  // From everyayah.com too (the Islamic Network has them by whole surahs
  // or not at all) — every ayah of each checked there, 2026-10-30.
  Reciter(
    'ar.husarymuallim',
    'Al-Husary (Muallim)',
    'الحصري (المعلّم)',
    128,
    everyAyah: 'Husary_Muallim_128kbps',
  ),
  Reciter(
    'ar.ghamdi',
    'Saad Al-Ghamdi',
    'سعد الغامدي',
    40,
    everyAyah: 'Ghamadi_40kbps',
  ),
  Reciter(
    'ar.dossary',
    'Yasser Al-Dossary',
    'ياسر الدوسري',
    128,
    everyAyah: 'Yasser_Ad-Dussary_128kbps',
  ),
  Reciter(
    'ar.qatami',
    'Nasser Al-Qatami',
    'ناصر القطامي',
    96,
    everyAyah: 'Nasser_Alqatami_128kbps',
  ),
  Reciter(
    'ar.abbad',
    'Fares Abbad',
    'فارس عباد',
    64,
    everyAyah: 'Fares_Abbad_64kbps',
  ),
  Reciter(
    'ar.alijaber',
    'Ali Jaber',
    'علي جابر',
    64,
    everyAyah: 'Ali_Jaber_64kbps',
  ),
  Reciter(
    'ar.bukhatir',
    'Salah Bukhatir',
    'صلاح بو خاطر',
    128,
    everyAyah: 'Salaah_AbdulRahman_Bukhatir_128kbps',
  ),
  Reciter(
    'ar.yassersalamah',
    'Yasser Salamah',
    'ياسر سلامة',
    128,
    everyAyah: 'Yaser_Salamah_128kbps',
  ),
  Reciter(
    'ar.mansoori',
    'Karim Mansoori',
    'كريم منصوري',
    40,
    everyAyah: 'Karim_Mansoori_40kbps',
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
  'ar.banna': 383583607,
  'ar.husarymuallim': 2752910232,
  'ar.ghamdi': 443859880,
  'ar.dossary': 1495802496,
  'ar.qatami': 1175429446,
  'ar.abbad': 616976338,
  'ar.alijaber': 727400695,
  'ar.bukhatir': 1378130847,
  'ar.yassersalamah': 1552740208,
  'ar.mansoori': 1052913291,
};

/// [reciter]'s download size, as "≈ 640 MB" / "≈ 1.2 GB"; `null` if
/// unknown.
String? reciterDownloadSize(Reciter reciter) {
  final bytes = reciterDownloadBytes[reciter.edition];
  return bytes == null ? null : _sizeLabel(bytes.toDouble());
}

String _sizeLabel(double bytes) {
  final mb = bytes / (1000 * 1000);
  if (mb >= 1000) return '≈ ${(mb / 1000).toStringAsFixed(1)} GB';
  // A short surah: tenths of a megabyte (not "≈ 0 MB").
  if (mb < 10) return '≈ ${mb.toStringAsFixed(1)} MB';
  return '≈ ${mb.round()} MB';
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

/// Each surah's share of the whole recitation (by its letters, as
/// [juzShare]), Al-Fatiha first — for its download size.
const surahShare = <double>[
  0.00043,
  0.07945,
  0.04527,
  0.04932,
  0.03689,
  0.03854,
  0.04367,
  0.01640,
  0.03358,
  0.02306,
  0.02369,
  0.02208,
  0.01073,
  0.01072,
  0.00867,
  0.02368,
  0.02013,
  0.01989,
  0.01186,
  0.01636,
  0.01527,
  0.01605,
  0.01349,
  0.01736,
  0.01173,
  0.01708,
  0.01455,
  0.01797,
  0.01305,
  0.01053,
  0.00654,
  0.00473,
  0.01740,
  0.01088,
  0.00976,
  0.00926,
  0.01174,
  0.00925,
  0.01468,
  0.01545,
  0.01023,
  0.01064,
  0.01089,
  0.00446,
  0.00628,
  0.00806,
  0.00732,
  0.00760,
  0.00462,
  0.00456,
  0.00467,
  0.00400,
  0.00436,
  0.00448,
  0.00508,
  0.00527,
  0.00768,
  0.00616,
  0.00592,
  0.00473,
  0.00290,
  0.00232,
  0.00241,
  0.00329,
  0.00363,
  0.00329,
  0.00408,
  0.00387,
  0.00341,
  0.00292,
  0.00292,
  0.00336,
  0.00261,
  0.00314,
  0.00205,
  0.00330,
  0.00252,
  0.00239,
  0.00237,
  0.00167,
  0.00132,
  0.00101,
  0.00228,
  0.00135,
  0.00142,
  0.00077,
  0.00091,
  0.00116,
  0.00176,
  0.00104,
  0.00077,
  0.00096,
  0.00051,
  0.00031,
  0.00048,
  0.00087,
  0.00034,
  0.00122,
  0.00048,
  0.00050,
  0.00048,
  0.00038,
  0.00022,
  0.00041,
  0.00029,
  0.00023,
  0.00035,
  0.00013,
  0.00029,
  0.00025,
  0.00025,
  0.00014,
  0.00022,
  0.00025,
];

/// Surah [surah]'s ayahs, as global ayah numbers.
Iterable<int> surahAyahNumbers(int surah) sync* {
  final first = globalAyahNumber(surah * 1000 + 1);
  for (var n = first; n < first + surahAyahCounts[surah - 1]; n++) {
    yield n;
  }
}

/// Surah [surah]'s download size for [reciter], as "≈ 3 MB"; `null` if
/// unknown.
String? surahDownloadSize(Reciter reciter, int surah) {
  final bytes = reciterDownloadBytes[reciter.edition];
  return bytes == null ? null : _sizeLabel(bytes * surahShare[surah - 1]);
}
