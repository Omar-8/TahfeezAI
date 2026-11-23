import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/gunzip.dart';

import '../../../quran/application/meaning_packs.dart';
import '../../../quran/application/quran_dataset_status.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/domain/search_normalizer.dart';
import '../../../quran/quran_providers.dart';
import '../../../quran/translation_providers.dart';
import '../../athkar/data/athkar_source.dart';
import '../domain/duas.dart';

/// A Quran dua as shown: each ayah's canonical words (from the installed
/// dataset, as every ayah in the app), and the shown translation's text.
typedef QuranDuaText = ({
  List<String> ayahs,
  List<String> translations,
  String? translationLanguage,
});

/// The hadith duas, bundled (built by tool/duas/build_hadith_duas.py).
const kHadithDuasAsset = 'assets/duas/hadith_duas.json.gz';

List<HadithDua> _parseHadiths(String raw) => [
  for (final h
      in (jsonDecode(raw) as Map<String, Object?>)['hadiths']! as List<Object?>)
    HadithDua.fromJson(h! as Map<String, Object?>),
];

/// The hadith duas, read once (off the main isolate).
final hadithDuasProvider = FutureProvider<List<HadithDua>>((ref) async {
  final data = await rootBundle.load(kHadithDuasAsset);
  final raw = await gunzipText(data.buffer.asUint8List());
  return compute(_parseHadiths, raw);
});

/// A translation's footnote marker ("[1]").
final _footnoteMarker = RegExp(r'\[\d+\]');

/// [QuranDuaText] of a dua — `null` while no Quran is installed.
final quranDuaTextProvider = FutureProvider.family<QuranDuaText?, QuranDua>((
  ref,
  dua,
) async {
  final installed = await ref.watch(hasInstalledQuranDatasetProvider.future);
  if (!installed) return null;
  final repository = ref.watch(quranRepositoryProvider);
  final script = ref.watch(quranScriptCodeProvider);
  final slugs = ref.watch(shownTranslationSlugsProvider);
  final translations = ref.watch(translationRepositoryProvider);
  final ayahs = <String>[];
  final meanings = <String>[];
  for (var v = dua.from; v <= dua.to; v++) {
    final words = await repository.getWordsForAyah(
      dua.surah * 1000 + v,
      scriptCode: script,
    );
    ayahs.add([for (final w in words) w.text].join(' '));
    if (slugs.isNotEmpty) {
      final t = await translations.getVerseText((
        chapterNo: dua.surah,
        verseNo: v,
      ), slug: slugs.first);
      // Its footnotes' markers ("[1]") left out: no footnotes here.
      if (t != null) meanings.add(t.text.replaceAll(_footnoteMarker, ''));
    }
  }
  return (
    ayahs: ayahs,
    translations: meanings,
    translationLanguage: slugs.isEmpty ? null : slugs.first.split('-').first,
  );
});

/// What the Duas page searches: each Quran dua's ayahs and translation,
/// and each of its Hisn al-Muslim chapters' words — their letters' forms
/// and marks aside.
final duasSearchIndexProvider =
    FutureProvider<
      ({
        Map<QuranDua, String> quran,
        Map<int, String> chapters,
        Map<String, String> hadiths,
      })
    >((ref) async {
      const normalizer = SearchNormalizer();
      final quran = <QuranDua, String>{};
      for (final d in DuaGroup.allQuran) {
        final text = await ref.watch(quranDuaTextProvider(d).future);
        if (text == null) continue;
        quran[d] = normalizer.normalizeArabic(
          [...text.ayahs, ...text.translations].join('\n'),
        );
      }
      final book = await ref.watch(athkarBookProvider.future);
      final chapters = <int, String>{};
      for (final g in DuaGroup.values) {
        for (final id in g.chapters) {
          final c = book.category(id);
          if (c == null) continue;
          chapters[id] = normalizer.normalizeArabic(
            [
              c.arabic,
              c.english,
              ?c.shortArabic,
              ?c.shortEnglish,
              for (final z in c.athkar) ...[z.arabic, z.english, z.note],
            ].join('\n'),
          );
        }
      }
      final hadiths = <String, String>{
        for (final h in await ref.watch(hadithDuasProvider.future))
          h.savedKey: normalizer.normalizeArabic(
            [h.arabic, ...h.translations.values].join('\n'),
          ),
      };
      return (quran: quran, chapters: chapters, hadiths: hadiths);
    });
