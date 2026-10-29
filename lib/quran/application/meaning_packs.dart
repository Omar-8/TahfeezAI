import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/storage/storage_providers.dart';
import '../../wbw/application/active_wbw_pack.dart';
import '../../wbw/application/arabic_word_gloss.dart';
import '../../wbw/application/wbw_preferences_controller.dart';
import '../../wbw/wbw_providers.dart';
import '../data/import/meaning_pack_store.dart';
import '../search_providers.dart';
import '../tafsir_providers.dart';
import '../translation_providers.dart';
import 'tafsir_selection_controller.dart';
import 'translation_selection_controller.dart';

class MeaningPacksState {
  const MeaningPacksState({this.busy = false, this.failure});

  /// Packs going on or off the phone (a short wait shown over the app).
  final bool busy;

  /// Why the last change failed (kept on screen until it works).
  final String? failure;
}

/// Keeps on the phone the text of the translations, tafsir and word
/// meanings in use — the chosen translations and tafsir, the word meanings
/// in the app's language (and English, for their transliteration), and
/// al-Sirāj's in Arabic — and takes the rest off ([MeaningPackStore]).
/// English's and Arabic's are always there ([MeaningPackKind.builtIn]).
/// Follows the app's language and the choices as they change. Android only
/// ([attach]ed at the start); elsewhere everything stays installed.
class MeaningPacksController extends Notifier<MeaningPacksState> {
  MeaningPackStore? _store;
  Timer? _debounce;
  Future<void> _chain = Future.value();

  @override
  MeaningPacksState build() {
    ref
      ..listen(translationSelectionControllerProvider, (_, _) => _schedule())
      ..listen(tafsirSelectionControllerProvider, (_, _) => _schedule())
      ..listen(wbwSelectedPackControllerProvider, (_, _) => _schedule())
      ..listen(localeControllerProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    return const MeaningPacksState();
  }

  /// Starts keeping the packs with [store]; done once the ones in use are
  /// on the phone (the splash waits for it at the first start).
  Future<void> attach(MeaningPackStore store) {
    _store = store;
    return _queue();
  }

  /// Tries the last failed change again.
  Future<void> retry() => _queue();

  // (A language change also changes the choices that follow it, a moment
  // later: one sync for both.)
  void _schedule() {
    if (_store == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _queue);
  }

  Future<void> _queue() =>
      _chain = _chain.then((_) => _sync()).catchError((_) {});

  Future<void> _sync() async {
    final store = _store;
    if (store == null || !ref.mounted) return;
    final wanted = await _wanted();
    if (!ref.mounted) return;
    final changes = <(MeaningPackKind, Set<String>, Set<String>)>[];
    for (final kind in MeaningPackKind.values) {
      final installed = await store.installed(kind);
      final available = await store.available(kind);
      final want = {...wanted[kind]!, ...kind.builtIn};
      final add = want.intersection(available).difference(installed);
      final remove = installed.difference(want);
      if (add.isNotEmpty || remove.isNotEmpty) {
        changes.add((kind, add, remove));
      }
    }
    if (changes.isEmpty) {
      if (state.failure != null && ref.mounted) {
        state = const MeaningPacksState();
      }
      return;
    }
    if (!ref.mounted) return;
    state = const MeaningPacksState(busy: true);
    // At least a moment: a wait that flickers past reads as a glitch.
    final shown = Future<void>.delayed(const Duration(milliseconds: 500));
    String? failure;
    try {
      for (final (kind, add, remove) in changes) {
        for (final id in remove) {
          await store.remove(kind, id);
          if (kind == MeaningPackKind.translation) {
            await ref.read(searchRepositoryProvider).removeTranslationIndex(id);
          }
        }
        for (final id in add) {
          await store.install(kind, id);
        }
      }
    } catch (e) {
      failure = '$e';
    }
    await shown;
    if (!ref.mounted) return;
    // The screens read the text anew.
    ref
      ..invalidate(translationRepositoryProvider)
      ..invalidate(tafsirRepositoryProvider)
      ..invalidate(wbwRepositoryProvider);
    state = MeaningPacksState(failure: failure);
  }

  Future<Map<MeaningPackKind, Set<String>>> _wanted() async {
    await Future.wait([
      ref.read(translationSelectionControllerProvider.notifier).restored,
      ref.read(tafsirSelectionControllerProvider.notifier).restored,
      ref.read(wbwSelectedPackControllerProvider.notifier).restored,
    ]);
    // The app's language (its stored choice, read directly: it may not be
    // restored yet), else the phone's.
    final language =
        ref.read(localeControllerProvider)?.languageCode ??
        await ref.read(browserStorageProvider).getString(localePrefKey) ??
        PlatformDispatcher.instance.locale.languageCode;
    final wbwChosen = ref.read(wbwSelectedPackControllerProvider);
    final tafsir = ref.read(tafsirSelectionControllerProvider);
    return {
      MeaningPackKind.translation: {
        ...ref.read(translationSelectionControllerProvider),
      },
      MeaningPackKind.tafsir: {?tafsir, if (language == 'ar') sirajTafsirId},
      MeaningPackKind.wbw: {
        englishWbwPackId,
        wbwChosen ?? '$language-qurancom',
      },
    };
  }
}

final meaningPacksProvider =
    NotifierProvider<MeaningPacksController, MeaningPacksState>(
      MeaningPacksController.new,
    );
