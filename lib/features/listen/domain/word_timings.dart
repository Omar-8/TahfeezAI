/// Where each word lies in a reciter's recording — Quran.com's word
/// timings ("segments"), to play a recitation mistake's correction as the
/// reciter recites it: the word with its neighbour, joined as recited,
/// rather than the word said alone.
library;

/// Quran.com's recitation id for each reciter it has word timings of, by
/// the app's reciter edition. Each recitation's timings are for the
/// everyayah.com ayah files — the same recordings the app streams (from the
/// Islamic Network or everyayah.com), checked 2026-11-01 to line up within
/// ~25 ms (durations within 0.1 s).
const quranComRecitations = {
  'ar.alafasy': 7,
  'ar.husary': 6,
  'ar.abdulbasitmurattal': 2,
  'ar.abdurrahmaansudais': 3,
  'ar.shaatree': 4,
  'ar.hanirifai': 5,
  'ar.minshawi': 9,
  'ar.saoodshuraym': 10,
  'ar.tablawi': 11,
  'ar.husarymuallim': 12,
};

/// Reciters Quran.com times by whole surah instead (its "qdc" reciter id):
/// the timings are for its own surah recordings, so a correction is cut
/// from that recording — the same voice, another file than the app's ayah.
const quranComSurahRecitations = {'ar.dossary': 97, 'ar.tunaiji': 161};

/// Whether [edition]'s word timings exist (else a correction is the word
/// alone).
bool hasWordTimings(String edition) =>
    quranComRecitations.containsKey(edition) ||
    quranComSurahRecitations.containsKey(edition);

/// A word's place in its recording, in milliseconds.
typedef WordSpan = ({int startMs, int endMs});

/// An ayah's word timings (Quran.com's word numbering) and the recording
/// they are for: the reciter's ayah file, or — [surahUrl] — the whole
/// surah's, the ayah lying from [fromMs] to [toMs] in it.
class AyahWordTimings {
  const AyahWordTimings(
    this.spans, {
    this.surahUrl,
    this.fromMs = 0,
    this.toMs,
  });

  final Map<int, WordSpan> spans;
  final String? surahUrl;
  final int fromMs;
  final int? toMs;
}

/// Quran.com's segments by word — each `[index, word, start, end]` (by
/// ayah) or `[word, start, end]` (by surah), the word 1-based in Quran.com's
/// numbering, numbers or numeric strings. Anything malformed is left out.
Map<int, WordSpan> parseWordSegments(Object? segments) {
  int? number(Object? v) => switch (v) {
    final num n => n.round(),
    final String s => num.tryParse(s)?.round(),
    _ => null,
  };
  final out = <int, WordSpan>{};
  if (segments is! List) return out;
  for (final s in segments) {
    if (s is! List || s.length < 3) continue;
    final at = s.length >= 4 ? 1 : 0;
    final word = number(s[at]),
        start = number(s[at + 1]),
        end = number(s[at + 2]);
    if (word == null || start == null || end == null || end <= start) {
      continue;
    }
    out[word] = (startMs: start, endMs: end);
  }
  return out;
}

/// Lead before the clip's first word and tail after its last: the timings
/// are within tens of milliseconds, and a word's first sound (a hamza, a
/// qalqala) is easily clipped.
const _leadMs = 150, _tailMs = 300;

/// What to play for word [position] (Quran.com's 1-based numbering) of
/// [timings]: the word and the next one — where a word's last vowel and the
/// rules joining it to the next (ghunnah, idgham, ikhfa, iqlab, madd
/// munfasil) are heard — and from the word before too when [fromPrevious]
/// (a mistake on its first letter, which the word before may join into).
/// The ayah's last word is the reciter's stop, as it would be the reader's.
/// In a surah recording, kept within the ayah (the lead and tail at most
/// reaching its silences). `null` when the word has no timing.
WordSpan? correctionClip(
  AyahWordTimings timings,
  int position, {
  bool fromPrevious = false,
}) {
  final spans = timings.spans;
  final word = spans[position];
  if (word == null) return null;
  final first = fromPrevious ? spans[position - 1] ?? word : word;
  final last = spans[position + 1] ?? word;
  var start = first.startMs - _leadMs;
  var end = last.endMs + _tailMs;
  final floor = timings.fromMs - _leadMs;
  if (start < floor) start = floor;
  if (start < 0) start = 0;
  final ceiling = timings.toMs;
  if (ceiling != null && end > ceiling + _leadMs) end = ceiling + _leadMs;
  return (startMs: start, endMs: end);
}

/// Quran.com's word timings of ayah [ayahId] by [recitation].
String wordTimingsUrl(int recitation, int ayahId) =>
    'https://api.quran.com/api/v4/recitations/$recitation/by_ayah/'
    '${ayahId ~/ 1000}:${ayahId % 1000}';

/// Quran.com's surah recordings by (qdc) [reciter], with their word
/// timings (`chapter` asks for one).
String surahTimingsUrl(int reciter) =>
    'https://api.qurancdn.com/api/qdc/audio/reciters/$reciter/audio_files';
