import 'package:tahfeez_ai/core/storage/browser_storage.dart';

/// [BrowserStorage] in memory.
class MemoryStorage implements BrowserStorage {
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
