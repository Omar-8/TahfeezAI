// The update offer: every time the app opens while Google Play has a newer
// version — "Later" does not hide it from the next opening — unless the
// offers are turned off in Settings.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/app_store/app_store_service.dart';
import 'package:tahfeez_ai/core/app_store/store_prompts.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';

class _Memory implements BrowserStorage {
  final values = <String, Object?>{};

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

class _Store implements AppStoreService {
  bool? available;

  @override
  Future<bool?> updateAvailable() async => available;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Memory storage;
  late _Store store;
  // Each opening of the app: a new StorePrompts on the same storage.
  StorePrompts opening() => StorePrompts(storage, store);

  setUp(() {
    storage = _Memory();
    store = _Store();
  });

  test('an update: offered at every opening, "Later" or not', () async {
    store.available = true;
    expect(await opening().shouldOfferUpdate(), isTrue);
    // Closed with "Later" (nothing kept), the app opened again.
    expect(await opening().shouldOfferUpdate(), isTrue);
    expect(await opening().shouldOfferUpdate(), isTrue);
  });

  test('none (or unknown): nothing offered', () async {
    store.available = false;
    expect(await opening().shouldOfferUpdate(), isFalse);
    store.available = null;
    expect(await opening().shouldOfferUpdate(), isFalse);
  });

  test('offers turned off in Settings: never offered', () async {
    store.available = true;
    await opening().setUpdateOffers(false);
    expect(await opening().shouldOfferUpdate(), isFalse);
    await opening().setUpdateOffers(true);
    expect(await opening().shouldOfferUpdate(), isTrue);
  });
}
