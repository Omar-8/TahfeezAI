import 'package:shared_preferences/shared_preferences.dart';

/// Small, synchronous-feeling key/value persistence that works identically
/// on Android, iOS, and Web.
///
/// This is the "browser persistence abstraction" called for by Milestone 1:
/// on the web, `shared_preferences` is backed by `window.localStorage`; on
/// Android/iOS it is backed by the native SharedPreferences/NSUserDefaults
/// stores. It is intentionally scoped to small values (preferences, flags,
/// the active locale/theme mode) — bulk downloaded resource data (Quran
/// datasets, audio, fonts) belongs in [FileStorage] on native platforms and
/// will get a dedicated large-blob strategy for the web (IndexedDB/OPFS) in
/// the Resource Manager milestone, not here.
abstract class BrowserStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);

  /// Removes every stored value except those under [keep] (Settings →
  /// Reset all data).
  Future<void> clearExcept(Set<String> keep);
}

class SharedPreferencesBrowserStorage implements BrowserStorage {
  const SharedPreferencesBrowserStorage();

  Future<SharedPreferencesAsync> get _prefs async => SharedPreferencesAsync();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  @override
  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await (await _prefs).setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }

  @override
  Future<void> clearExcept(Set<String> keep) async {
    final prefs = await _prefs;
    final keys = await prefs.getKeys();
    await prefs.clear(allowList: keys.difference(keep));
  }
}
