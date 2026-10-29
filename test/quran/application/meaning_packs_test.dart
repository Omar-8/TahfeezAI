import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
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
  _Store()
    : super(
        databases: const {},
        temp: Directory.systemTemp,
        loadString: (_) async => '',
        unpack: (_, _) async => '',
      );

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

  Future<ProviderContainer> start(Map<String, Object?> stored) async {
    store = _Store();
    search = _Search();
    final c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(_Memory(stored)),
        searchRepositoryProvider.overrideWithValue(search),
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
}
