import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wbw/application/active_wbw_pack.dart';
import '../../wbw/wbw_providers.dart';
import '../domain/models/translation_models.dart';
import '../translation_providers.dart';
import 'translation_selection_controller.dart';

/// An ayah's chosen translations (Settings), by slug — for readers that
/// show one ayah at a time (the tafsir reader).
final ayahTranslationsProvider = FutureProvider.autoDispose
    .family<Map<String, TranslationVerseText>, int>((ref, ayahId) async {
      final slugs = ref.watch(translationSelectionControllerProvider);
      final repository = ref.watch(translationRepositoryProvider);
      final verse = (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000);
      final out = <String, TranslationVerseText>{};
      for (final slug in slugs) {
        final text = await repository.getVerseText(verse, slug: slug);
        if (text != null) out[slug] = text;
      }
      return out;
    });

/// An ayah's transliteration, word by word from the chosen word-by-word
/// pack (else any installed pack that has one); `null` without one.
final ayahTransliterationProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, ayahId) async {
      final repository = ref.watch(wbwRepositoryProvider);
      var pack = await ref.watch(activeWbwPackProvider.future);
      if (pack == null || !pack.hasTransliteration) {
        final installed = await repository.getInstalledPacks();
        pack = installed.where((p) => p.hasTransliteration).firstOrNull;
      }
      if (pack == null) return null;
      final words = await repository.getAyahWords(
        packId: pack.id,
        ayahId: ayahId,
      );
      final text = [
        for (final w in words)
          if (w.transliteration case final t? when t.trim().isNotEmpty) t.trim(),
      ].join(' ');
      return text.isEmpty ? null : text;
    });
