import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/acoustic/quran_acoustic_verifier.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../quran/domain/models/quran_refs.dart';
import 'acoustic_verification_controller.dart';

/// Each word's pronunciation mistakes as its last recitation heard them
/// (which letter; expected, heard; the tajweed rule) — kept on the phone
/// with the page's colours, so a word sheet opened on an earlier session's
/// orange word still says what was wrong (owner, 2026-11-16: it said only
/// "a pronunciation mistake was found"). A word recited again replaces its
/// own (none heard: none kept).
class KeptWordErrorsController
    extends Notifier<Map<WordRef, List<RecitationError>>> {
  static const storageKey = 'mushaf.progress.errors.v1';

  /// The most words kept (the oldest dropped first).
  static const limit = 3000;

  Timer? _save;

  @override
  Map<WordRef, List<RecitationError>> build() {
    ref.onDispose(() => _save?.cancel());
    ref.listen(acousticVerificationControllerProvider.select((s) => s.words), (
      was,
      words,
    ) {
      final changed = <WordRef, List<RecitationError>>{
        for (final MapEntry(key: word, value: result) in words.entries)
          // (A quick check's early verdict waits for its ayah's.)
          if (!result.provisional && !identical(was?[word], result))
            word: [
              for (final e in result.errors)
                if (e.type.isError) e,
            ],
      };
      if (changed.isEmpty) return;
      final next = {...state}..removeWhere((w, _) => changed.containsKey(w));
      for (final MapEntry(key: w, value: errors) in changed.entries) {
        if (errors.isNotEmpty) next[w] = errors;
      }
      while (next.length > limit) {
        next.remove(next.keys.first);
      }
      state = next;
      _saveSoon();
    });
    unawaited(_restore());
    return const {};
  }

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    if (raw == null || !ref.mounted) return;
    try {
      final saved = decode(jsonDecode(raw));
      // (Heard meanwhile: newer than the saved.)
      state = {...saved, ...state};
    } on Object {
      // Unreadable: none.
    }
  }

  void _saveSoon() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), () {
      if (!ref.mounted) return;
      unawaited(
        ref
            .read(browserStorageProvider)
            .setString(storageKey, jsonEncode(encode(state))),
      );
    });
  }

  /// [errors] as stored: by word ("ayahId:wordIndex"), each mistake's
  /// letter, kind, expected and heard sounds, rule.
  static Map<String, Object?> encode(
    Map<WordRef, List<RecitationError>> errors,
  ) => {
    for (final MapEntry(key: w, value: list) in errors.entries)
      '${w.ayahId}:${w.wordIndex}': [
        for (final e in list)
          {
            'l': e.letter,
            't': e.type.name,
            'e': e.expected,
            'o': ?e.observed,
            'r': ?e.rule?.name,
            'p': e.likelihoodRatio,
          },
      ],
  };

  static Map<WordRef, List<RecitationError>> decode(Object? json) {
    if (json is! Map) return const {};
    final out = <WordRef, List<RecitationError>>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final parts = '$key'.split(':');
      if (parts.length != 2 || value is! List) continue;
      final ayah = int.tryParse(parts[0]), index = int.tryParse(parts[1]);
      if (ayah == null || index == null) continue;
      final word = (ayahId: ayah, wordIndex: index);
      final list = <RecitationError>[];
      for (final e in value) {
        if (e is! Map) continue;
        final type = RecitationErrorType.values
            .where((t) => t.name == e['t'])
            .firstOrNull;
        final letter = e['l'], expected = e['e'];
        if (type == null || letter is! int || expected is! String) continue;
        list.add(
          RecitationError(
            word: word,
            letter: letter,
            type: type,
            expected: expected,
            observed: e['o'] is String ? e['o'] as String : null,
            likelihoodRatio: (e['p'] as num?)?.toDouble() ?? 0,
            rule: TajweedRule.values.where((r) => r.name == e['r']).firstOrNull,
          ),
        );
      }
      if (list.isNotEmpty) out[word] = list;
    }
    return out;
  }
}

final keptWordErrorsProvider =
    NotifierProvider<
      KeptWordErrorsController,
      Map<WordRef, List<RecitationError>>
    >(KeptWordErrorsController.new);
