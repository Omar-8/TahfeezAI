import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core_providers.dart';
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

/// A pack, as `kind:id` (the sets below).
String meaningPackKey(MeaningPackKind kind, String id) => '${kind.name}:$id';

class MeaningPacksState {
  const MeaningPacksState({
    this.busy = false,
    this.failure,
    this.missing = const {},
    this.downloading = const {},
    this.waitingForNetwork = false,
    this.kept = const {},
  });

  /// Packs going on or off (the web's imports: a short wait shown over the
  /// app). Downloads never dim the app.
  final bool busy;

  /// Why the last change failed (kept on screen until it works). Not for
  /// want of a network: that's [waitingForNetwork].
  final String? failure;

  /// Packs in use not on the device yet ([meaningPackKey]s): English is
  /// shown in their place meanwhile ([shownTranslationSlugsProvider],
  /// [shownTafsirIdProvider]).
  final Set<String> missing;

  /// Packs downloading now.
  final Set<String> downloading;

  /// A download waits for the phone to be online (tried again then).
  final bool waitingForNetwork;

  /// Packs downloaded by hand: kept until deleted.
  final Set<String> kept;

  MeaningPacksState copyWith({
    bool? busy,
    String? Function()? failure,
    Set<String>? missing,
    Set<String>? downloading,
    bool? waitingForNetwork,
    Set<String>? kept,
  }) => MeaningPacksState(
    busy: busy ?? this.busy,
    failure: failure == null ? this.failure : failure(),
    missing: missing ?? this.missing,
    downloading: downloading ?? this.downloading,
    waitingForNetwork: waitingForNetwork ?? this.waitingForNetwork,
    kept: kept ?? this.kept,
  );
}

/// Keeps on the device the text of the translations, tafsir and word
/// meanings in use — the chosen translations and tafsir, the word meanings
/// in the app's language (and English, for their transliteration), and
/// al-Sirāj's in Arabic — and the ones downloaded by hand
/// ([download]: kept until [delete]d). The rest comes off: a language left
/// (back to English or Arabic, or to another) takes its packs with it.
/// English's and Arabic's are built in ([MeaningPackKind.builtIn]).
///
/// On the phones a pack is a download ([MeaningPackStore.downloads]): in
/// the background, the app usable meanwhile (English in its place); with no
/// network it waits, and goes on when the phone is online again.
class MeaningPacksController extends Notifier<MeaningPacksState> {
  MeaningPackStore? _store;
  Timer? _debounce;
  StreamSubscription<bool>? _online;
  Future<void> _chain = Future.value();

  /// The packs downloaded by hand, as stored.
  static const keptKey = 'meaning_packs.kept';

  @override
  MeaningPacksState build() {
    ref
      ..listen(translationSelectionControllerProvider, (_, _) => _schedule())
      ..listen(tafsirSelectionControllerProvider, (_, _) => _schedule())
      ..listen(wbwSelectedPackControllerProvider, (_, _) => _schedule())
      ..listen(localeControllerProvider, (_, _) => _schedule());
    ref.onDispose(() {
      _debounce?.cancel();
      _online?.cancel();
    });
    return const MeaningPacksState();
  }

  /// The store in use (`null` before [attach]).
  MeaningPackStore? get store => _store;

  /// Starts keeping the packs with [store]; done once the ones in use are
  /// on the device — or, downloads, once they were tried.
  Future<void> attach(MeaningPackStore store) async {
    _store = store;
    final stored = await ref.read(browserStorageProvider).getString(keptKey);
    if (!ref.mounted) return;
    if (stored != null) {
      try {
        state = state.copyWith(
          kept: {...(jsonDecode(stored) as List).cast<String>()},
        );
      } on FormatException {
        // (Unreadable: none kept.)
      }
    }
    if (store.downloads) {
      _online = ref
          .read(connectivityServiceProvider)
          .onConnectivityChanged
          .listen((online) {
            if (online && state.waitingForNetwork) _queue();
          });
    }
    return _queue();
  }

  /// Tries the last failed change again.
  Future<void> retry() => _queue();

  /// Downloads [id] and keeps it until it's [delete]d.
  Future<void> download(MeaningPackKind kind, String id) async {
    await _keep({...state.kept, meaningPackKey(kind, id)});
    return _queue();
  }

  /// Takes [id] off the device — no longer kept, and no longer chosen (a
  /// translation unchecked; a tafsir, none; word meanings, English's).
  /// Never a built-in one.
  Future<void> delete(MeaningPackKind kind, String id) async {
    if (kind.builtIn.contains(id)) return;
    await _keep({...state.kept}..remove(meaningPackKey(kind, id)));
    switch (kind) {
      case MeaningPackKind.translation:
        final notifier = ref.read(
          translationSelectionControllerProvider.notifier,
        );
        if (ref.read(translationSelectionControllerProvider).contains(id)) {
          await notifier.toggle(id);
        }
      case MeaningPackKind.tafsir:
        if (ref.read(tafsirSelectionControllerProvider) == id) {
          await ref
              .read(tafsirSelectionControllerProvider.notifier)
              .select(null);
        }
      case MeaningPackKind.wbw:
        if ((await _wanted())[MeaningPackKind.wbw]!.contains(id)) {
          await ref
              .read(wbwSelectedPackControllerProvider.notifier)
              .select(englishWbwPackId);
        }
    }
    return _queue();
  }

  Future<void> _keep(Set<String> kept) async {
    state = state.copyWith(kept: kept);
    await ref
        .read(browserStorageProvider)
        .setString(keptKey, jsonEncode(kept.toList()..sort()));
  }

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
    final adds = <(MeaningPackKind, String)>[];
    final removes = <(MeaningPackKind, String)>[];
    for (final kind in MeaningPackKind.values) {
      final installed = await store.installed(kind);
      final available = await store.available(kind);
      final want = {
        ...wanted[kind]!,
        ...kind.builtIn,
        for (final key in state.kept)
          if (key.startsWith('${kind.name}:'))
            key.substring(kind.name.length + 1),
      };
      for (final id in want.intersection(available).difference(installed)) {
        adds.add((kind, id));
      }
      for (final id in installed.difference(want)) {
        removes.add((kind, id));
      }
    }
    if (!ref.mounted) return;
    if (adds.isEmpty && removes.isEmpty) {
      state = state.copyWith(
        failure: () => null,
        missing: const {},
        waitingForNetwork: false,
      );
      return;
    }
    if (store.downloads) {
      return _download(store, adds, removes);
    }
    state = state.copyWith(busy: true);
    // At least a moment: a wait that flickers past reads as a glitch.
    final shown = Future<void>.delayed(const Duration(milliseconds: 500));
    String? failure;
    try {
      for (final (kind, id) in removes) {
        await _remove(store, kind, id);
      }
      for (final (kind, id) in adds) {
        await store.install(kind, id);
      }
    } catch (e) {
      failure = '$e';
    }
    await shown;
    if (!ref.mounted) return;
    _reread();
    state = state.copyWith(busy: false, failure: () => failure);
  }

  /// The phones': what's no longer wanted comes off at once; the rest is
  /// downloaded one by one, each shown as it arrives.
  Future<void> _download(
    MeaningPackStore store,
    List<(MeaningPackKind, String)> adds,
    List<(MeaningPackKind, String)> removes,
  ) async {
    for (final (kind, id) in removes) {
      await _remove(store, kind, id);
    }
    if (removes.isNotEmpty) _reread();
    var missing = {for (final (kind, id) in adds) meaningPackKey(kind, id)};
    state = state.copyWith(
      missing: missing,
      failure: () => null,
      waitingForNetwork: false,
    );
    String? failure;
    var offline = false;
    for (final (kind, id) in adds) {
      final key = meaningPackKey(kind, id);
      state = state.copyWith(downloading: {key});
      try {
        await store.install(kind, id);
        missing = {...missing}..remove(key);
        _reread();
      } on MeaningPackOffline {
        // (The rest would wait too.)
        offline = true;
        break;
      } catch (e) {
        failure ??= '$e';
      }
      if (!ref.mounted) return;
      state = state.copyWith(missing: missing);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      missing: missing,
      downloading: const {},
      waitingForNetwork: offline,
      failure: () => failure,
    );
  }

  Future<void> _remove(
    MeaningPackStore store,
    MeaningPackKind kind,
    String id,
  ) async {
    await store.remove(kind, id);
    if (kind == MeaningPackKind.translation) {
      await ref.read(searchRepositoryProvider).removeTranslationIndex(id);
    }
  }

  /// The screens read the text anew.
  void _reread() {
    if (!ref.mounted) return;
    ref
      ..invalidate(translationRepositoryProvider)
      ..invalidate(tafsirRepositoryProvider)
      ..invalidate(wbwRepositoryProvider);
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

/// The translations shown: the chosen ones on the device; while none of
/// them is yet (downloading, or waiting for the network), English's.
final shownTranslationSlugsProvider = Provider<List<String>>((ref) {
  final chosen = ref.watch(translationSelectionControllerProvider);
  final missing = ref.watch(meaningPacksProvider.select((s) => s.missing));
  final shown = [
    for (final slug in chosen)
      if (!missing.contains(meaningPackKey(MeaningPackKind.translation, slug)))
        slug,
  ];
  return shown.isEmpty && chosen.isNotEmpty ? const ['en-rowwad'] : shown;
});

/// The tafsir shown: the chosen one, or — while it isn't on the device yet
/// — English's Al-Mukhtasar.
final shownTafsirIdProvider = Provider<String?>((ref) {
  final chosen = ref.watch(tafsirSelectionControllerProvider);
  final missing = ref.watch(meaningPacksProvider.select((s) => s.missing));
  if (chosen != null &&
      missing.contains(meaningPackKey(MeaningPackKind.tafsir, chosen))) {
    return 'en-mukhtasar';
  }
  return chosen;
});

/// What the lists show beside a pack.
enum MeaningPackStatus {
  /// English's or Arabic's: always there.
  builtIn,

  /// On the device (deletable).
  installed,

  /// Downloading now (or waiting its turn).
  downloading,

  /// Not on the device (downloadable).
  notInstalled,
}

/// Each pack of [kind]'s status and download size (bytes), for the lists;
/// empty where packs aren't downloads (the web).
final meaningPackInfoProvider = FutureProvider.autoDispose
    .family<
      Map<String, ({MeaningPackStatus status, int? bytes})>,
      MeaningPackKind
    >((ref, kind) async {
      final packs = ref.watch(meaningPacksProvider);
      final store = ref.read(meaningPacksProvider.notifier).store;
      if (store == null || !store.downloads) return const {};
      final installed = await store.installed(kind);
      final available = await store.available(kind);
      return {
        for (final id in kind.builtIn)
          id: (status: MeaningPackStatus.builtIn, bytes: null),
        for (final id in available)
          id: (
            // (Waiting for the network: shown downloadable — a tap tries
            // again.)
            status:
                packs.downloading.contains(meaningPackKey(kind, id)) ||
                    (packs.missing.contains(meaningPackKey(kind, id)) &&
                        !packs.waitingForNetwork)
                ? MeaningPackStatus.downloading
                : installed.contains(id)
                ? MeaningPackStatus.installed
                : MeaningPackStatus.notInstalled,
            bytes: await store.downloadBytes(kind, id),
          ),
      };
    });
