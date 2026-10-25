import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/meaning_language_follower.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/application/translation_selection_controller.dart';
import 'package:tahfeez_ai/wbw/application/wbw_preferences_controller.dart';

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

void main() {
  // The test phone's language is English.
  Future<ProviderContainer> start(_Memory storage) async {
    final c = ProviderContainer(
      overrides: [browserStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    c.listen(meaningLanguageFollowerProvider, (_, _) {});
    c.read(translationSelectionControllerProvider);
    c.read(tafsirSelectionControllerProvider);
    c.read(wbwSelectedPackControllerProvider);
    await pumpEventQueue();
    return c;
  }

  Future<void> switchTo(ProviderContainer c, String code) async {
    await c.read(localeControllerProvider.notifier).setLocale(Locale(code));
    await pumpEventQueue();
  }

  test('switched to Arabic: the defaults become Arabic', () async {
    final c = await start(_Memory());
    expect(c.read(translationSelectionControllerProvider), ['en-rowwad']);
    await switchTo(c, 'ar');
    expect(c.read(translationSelectionControllerProvider), isEmpty);
    expect(c.read(tafsirSelectionControllerProvider), 'ar-muyassar');
  });

  test('one set to another language stays; the rest follow', () async {
    final c = await start(
      _Memory({
        'translation.active_slugs': 'ur-junagarhi',
        'tafsir.active_id': 'en-mukhtasar',
        'wbw.selected_pack_id': 'en-qurancom',
      }),
    );
    await switchTo(c, 'tr');
    expect(c.read(translationSelectionControllerProvider), ['ur-junagarhi']);
    expect(c.read(tafsirSelectionControllerProvider), 'tr-mukhtasar');
    expect(c.read(wbwSelectedPackControllerProvider), isNull);
  });

  test('opened with Arabic chosen before: the meanings are Arabic', () async {
    final storage = _Memory({'core.locale': 'ar'});
    final c = await start(storage);
    expect(c.read(translationSelectionControllerProvider), isEmpty);
    expect(c.read(tafsirSelectionControllerProvider), 'ar-muyassar');
    expect(storage.values[MeaningLanguageFollower.storageKey], 'ar');
  });
}
