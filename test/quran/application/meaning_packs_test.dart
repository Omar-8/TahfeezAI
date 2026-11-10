import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/networking/connectivity_service.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/application/translation_selection_controller.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/meaning_language_follower.dart';
import 'package:tahfeez_ai/quran/application/meaning_packs.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';
import 'package:tahfeez_ai/quran/domain/repositories/search_repository.dart';
import 'package:tahfeez_ai/quran/search_providers.dart';

class _Memory implements BrowserStorage {
  _Memory([Map<String, Object?>? values]) : values = {...?values};

  final Map<String, Object?> values;

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> clearExcept(Set<String> keep) async =>
      values.removeWhere((k, _) => !keep.contains(k));
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<void> writeAll(Map<String, Object?> v) async => values.addAll(v);
}

/// The packs on the phone, as sets — English's and Arabic's from the start.
class _Store extends MeaningPackStore {
  _Store({this.downloads = false})
    : super(databases: const {}, loadString: (_) async => '');

  /// The phones': packs downloaded.
  @override
  final bool downloads;

  /// No network: a download fails as the phone's would.
  bool offline = false;

  @override
  Future<int?> downloadBytes(MeaningPackKind kind, String id) async => 345216;

  final on = {
    for (final kind in MeaningPackKind.values) kind: {...kind.builtIn},
  };
  final log = <String>[];
  Completer<void>? hold;

  @override
  Future<Set<String>> available(MeaningPackKind kind) async => switch (kind) {
    MeaningPackKind.translation => {'de-rowwad', 'fr-noor', 'ur-junagarhi'},
    MeaningPackKind.tafsir => {'fr-mukhtasar', 'ur-ahsanulbayan'},
    MeaningPackKind.wbw => {'fr-qurancom', 'ur-qurancom'},
  };

  @override
  Future<Set<String>> installed(MeaningPackKind kind) async => {...on[kind]!};

  @override
  Future<void> install(MeaningPackKind kind, String id) async {
    await hold?.future;
    if (offline) throw const MeaningPackOffline('no network');
    log.add('+$id');
    on[kind]!.add(id);
  }

  @override
  Future<void> remove(MeaningPackKind kind, String id) async {
    if (kind.builtIn.contains(id)) return;
    log.add('-$id');
    on[kind]!.remove(id);
  }
}

class _Connectivity implements ConnectivityService {
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onConnectivityChanged => changes.stream;
}

class _Search implements SearchRepository {
  final removed = <String>[];

  @override
  Future<void> removeTranslationIndex(String slug) async => removed.add(slug);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Store store;
  late _Search search;

  late _Connectivity connectivity;
  late _Memory memory;

  Future<ProviderContainer> start(
    Map<String, Object?> stored, {
    bool downloads = false,
    bool offline = false,
  }) async {
    store = _Store(downloads: downloads)..offline = offline;
    search = _Search();
    connectivity = _Connectivity();
    memory = _Memory(stored);
    final c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(memory),
        searchRepositoryProvider.overrideWithValue(search),
        connectivityServiceProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(c.dispose);
    c.listen(meaningLanguageFollowerProvider, (_, _) {});
    await c.read(meaningPacksProvider.notifier).attach(store);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(seconds: 1));

  test('English: nothing to unpack, nothing taken off', () async {
    await start({});
    expect(store.log, isEmpty);
  });

  test('opened with German chosen: its translation unpacked', () async {
    await start({'core.locale': 'de'});
    // (The choices follow the language a moment after the start.)
    await settle();
    expect(store.log, ['+de-rowwad']);
  });

  test('German to French: French goes on, German comes off', () async {
    final c = await start({'core.locale': 'de'});
    await settle();
    store.log.clear();
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('fr'));
    await settle();
    expect(
      store.log,
      containsAll(['-de-rowwad', '+fr-noor', '+fr-mukhtasar', '+fr-qurancom']),
    );
    expect(search.removed, ['de-rowwad']);
    expect(c.read(meaningPacksProvider).busy, isFalse);
    // Back to English: only the built-in ones are left.
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await settle();
    for (final kind in MeaningPackKind.values) {
      expect(store.on[kind], kind.builtIn);
    }
  });

  test('a wait is shown while a language goes on', () async {
    final c = await start({});
    store.hold = Completer<void>();
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ur'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(c.read(meaningPacksProvider).busy, isTrue);
    store.hold!.complete();
    await settle();
    expect(c.read(meaningPacksProvider).busy, isFalse);
    expect(store.on[MeaningPackKind.translation], contains('ur-junagarhi'));
  });

  group('the phones: packs downloaded', () {
    const fr = {'+fr-noor', '+fr-mukhtasar', '+fr-qurancom'};

    test('switched to French: its packs download by themselves — the app '
        'never dimmed', () async {
      final c = await start({}, downloads: true);
      final busy = <bool>[];
      c.listen(meaningPacksProvider.select((s) => s.busy), (_, b) {
        busy.add(b);
      });
      await c
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('fr'));
      await settle();
      expect(store.log.toSet(), fr);
      expect(busy, isNot(contains(true)));
      expect(c.read(meaningPacksProvider).missing, isEmpty);
    });

    for (final back in ['en', 'ar']) {
      test('French, then back to ${back == 'en' ? 'English' : 'Arabic'}: '
          "French's packs deleted by themselves", () async {
        final c = await start({'core.locale': 'fr'}, downloads: true);
        await settle();
        expect(store.log.toSet(), fr);
        store.log.clear();
        await c.read(localeControllerProvider.notifier).setLocale(Locale(back));
        await settle();
        expect(store.log.toSet(), {
          '-fr-noor',
          '-fr-mukhtasar',
          '-fr-qurancom',
        });
        for (final kind in MeaningPackKind.values) {
          expect(store.on[kind], kind.builtIn);
        }
        expect(search.removed, ['fr-noor']);
      });
    }

    test('a pack downloaded by hand stays through language changes, until '
        "it's deleted", () async {
      final c = await start({}, downloads: true);
      final packs = c.read(meaningPacksProvider.notifier);
      await packs.download(MeaningPackKind.tafsir, 'ur-ahsanulbayan');
      expect(store.on[MeaningPackKind.tafsir], contains('ur-ahsanulbayan'));
      // Kept across a restart.
      expect(
        memory.values[MeaningPacksController.keptKey],
        contains('tafsir:ur-ahsanulbayan'),
      );
      await c
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('fr'));
      await settle();
      await c
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('en'));
      await settle();
      expect(store.on[MeaningPackKind.tafsir], contains('ur-ahsanulbayan'));
      await packs.delete(MeaningPackKind.tafsir, 'ur-ahsanulbayan');
      expect(
        store.on[MeaningPackKind.tafsir],
        isNot(contains('ur-ahsanulbayan')),
      );
      expect(
        memory.values[MeaningPacksController.keptKey],
        isNot(contains('ur-ahsanulbayan')),
      );
    });

    test('kept packs remembered at the next start', () async {
      await start({
        MeaningPacksController.keptKey: '["translation:ur-junagarhi"]',
      }, downloads: true);
      expect(store.on[MeaningPackKind.translation], contains('ur-junagarhi'));
    });

    test('a chosen pack deleted: unchosen too (a tafsir: none)', () async {
      final c = await start({'core.locale': 'fr'}, downloads: true);
      await settle();
      final packs = c.read(meaningPacksProvider.notifier);
      await packs.delete(MeaningPackKind.translation, 'fr-noor');
      await packs.delete(MeaningPackKind.tafsir, 'fr-mukhtasar');
      await settle();
      expect(
        c.read(translationSelectionControllerProvider),
        isNot(contains('fr-noor')),
      );
      expect(c.read(tafsirSelectionControllerProvider), isNull);
      expect(store.on[MeaningPackKind.translation], isNot(contains('fr-noor')));
      expect(store.on[MeaningPackKind.tafsir], isNot(contains('fr-mukhtasar')));
    });

    test('word meanings deleted: English\'s in their place', () async {
      final c = await start({'core.locale': 'fr'}, downloads: true);
      await settle();
      await c
          .read(meaningPacksProvider.notifier)
          .delete(MeaningPackKind.wbw, 'fr-qurancom');
      await settle();
      expect(store.on[MeaningPackKind.wbw], MeaningPackKind.wbw.builtIn);
    });

    test('built-in packs are never deleted', () async {
      final c = await start({}, downloads: true);
      await c
          .read(meaningPacksProvider.notifier)
          .delete(MeaningPackKind.translation, 'en-rowwad');
      expect(store.on[MeaningPackKind.translation], contains('en-rowwad'));
    });

    test('offline: English shown meanwhile; online again, the packs '
        'download by themselves', () async {
      final c = await start(
        {'core.locale': 'fr'},
        downloads: true,
        offline: true,
      );
      await settle();
      final state = c.read(meaningPacksProvider);
      expect(state.waitingForNetwork, isTrue);
      expect(state.failure, isNull, reason: 'no error for want of a network');
      expect(state.missing, contains('translation:fr-noor'));
      expect(c.read(shownTranslationSlugsProvider), ['en-rowwad']);
      expect(c.read(shownTafsirIdProvider), 'en-mukhtasar');

      store.offline = false;
      connectivity.changes.add(true);
      await settle();
      expect(store.log.toSet(), fr);
      expect(c.read(meaningPacksProvider).waitingForNetwork, isFalse);
      expect(c.read(meaningPacksProvider).missing, isEmpty);
      expect(c.read(shownTranslationSlugsProvider), ['fr-noor']);
      expect(c.read(shownTafsirIdProvider), 'fr-mukhtasar');
    });

    test("another failure (a pack not published) is said, with the rest "
        'still downloaded', () async {
      final c = await start({}, downloads: true);
      store.hold = null;
      final failing = _FailingStore();
      await c.read(meaningPacksProvider.notifier).attach(failing);
      await c
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('fr'));
      await settle();
      expect(c.read(meaningPacksProvider).failure, contains('404'));
      expect(failing.on[MeaningPackKind.tafsir], contains('fr-mukhtasar'));
      expect(c.read(meaningPacksProvider).waitingForNetwork, isFalse);
    });

    test(
      "the lists' statuses: built in, on the phone, downloading, not",
      () async {
        final c = await start({'core.locale': 'fr'}, downloads: true);
        await settle();
        store.hold = Completer<void>();
        unawaited(
          c
              .read(meaningPacksProvider.notifier)
              .download(MeaningPackKind.translation, 'ur-junagarhi'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final info = await c.read(
          meaningPackInfoProvider(MeaningPackKind.translation).future,
        );
        expect(info['en-rowwad']!.status, MeaningPackStatus.builtIn);
        expect(info['fr-noor']!.status, MeaningPackStatus.installed);
        expect(info['ur-junagarhi']!.status, MeaningPackStatus.downloading);
        expect(info['de-rowwad']!.status, MeaningPackStatus.notInstalled);
        expect(info['de-rowwad']!.bytes, 345216);
        store.hold!.complete();
        await settle();
      },
    );
  });

  test('the web: no statuses (everything comes with the app)', () async {
    final c = await start({});
    expect(
      await c.read(meaningPackInfoProvider(MeaningPackKind.translation).future),
      isEmpty,
    );
  });
}

/// French's translation not published (404); the rest fine.
class _FailingStore extends _Store {
  _FailingStore() : super(downloads: true);

  @override
  Future<void> install(MeaningPackKind kind, String id) async {
    if (id == 'fr-noor') {
      throw StateError('Downloading translation-fr-noor failed: 404');
    }
    await super.install(kind, id);
  }
}
