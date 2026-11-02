import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/storage/browser_storage.dart';
import '../../../quran/domain/models/quran_refs.dart';
import 'mushaf_word_overlay.dart';

/// A memorization session's progress on the Mushaf, kept on the phone so
/// it survives the app being closed (or closed by the system while in the
/// background): hide mode and the words uncovered on each page, and the
/// last finished recitation's colours. Restored once, when the app starts.
class MushafProgressStore {
  MushafProgressStore(this._storage);

  final BrowserStorage _storage;

  static const hideKey = 'mushaf.progress.hide.v1';
  static const resultsKey = 'mushaf.progress.results.v1';

  static final _restored = <String>{};

  /// Whether [key] is still to be restored in this run of the app (once).
  static bool restoreOnce(String key) => _restored.add(key);

  @visibleForTesting
  static void resetRestored() => _restored.clear();

  // ---- hide mode ----

  Future<void> saveHide({
    required bool enabled,
    required Map<int, int> revealed,
    required Map<int, int> startOn,
  }) => _write(
    hideKey,
    enabled || revealed.isNotEmpty
        ? {
            'enabled': enabled,
            'revealed': {for (final e in revealed.entries) '${e.key}': e.value},
            'startOn': {for (final e in startOn.entries) '${e.key}': e.value},
          }
        : null,
  );

  Future<({bool enabled, Map<int, int> revealed, Map<int, int> startOn})?>
  loadHide() async {
    final json = await _read(hideKey);
    if (json == null) return null;
    Map<int, int> pages(Object? m) => {
      if (m is Map)
        for (final e in m.entries)
          if (int.tryParse('${e.key}') case final page? when e.value is int)
            page: e.value as int,
    };
    return (
      enabled: json['enabled'] == true,
      revealed: pages(json['revealed']),
      startOn: pages(json['startOn']),
    );
  }

  // ---- a finished recitation's colours ----

  Future<void> saveResults(MushafWordOverlay? overlay) => _write(
    resultsKey,
    overlay == null
        ? null
        : {
            'first': _ref(overlay.first),
            'last': _ref(overlay.last),
            'marks': {
              for (final e in overlay.marks.entries) _ref(e.key): e.value.name,
            },
            'heard': {
              for (final e in overlay.heard.entries) _ref(e.key): e.value,
            },
            'corrected': [for (final r in overlay.corrected) _ref(r)],
            'inks': {for (final e in overlay.inks.entries) e.key.name: e.value},
          },
  );

  Future<MushafWordOverlay?> loadResults() async {
    final json = await _read(resultsKey);
    final first = _parse(json?['first']), last = _parse(json?['last']);
    if (json == null || first == null || last == null) return null;
    MushafWordMark? mark(Object? name) =>
        MushafWordMark.values.where((m) => m.name == name).firstOrNull;
    final marks = <WordRef, MushafWordMark>{
      if (json['marks'] case final Map m)
        for (final e in m.entries)
          if ((_parse(e.key), mark(e.value)) case (final r?, final k?)) r: k,
    };
    return MushafWordOverlay(
      first: first,
      last: last,
      marks: marks,
      hideUnrevealed: false,
      followHideMode: true,
      heard: {
        if (json['heard'] case final Map m)
          for (final e in m.entries)
            if (_parse(e.key) case final r? when e.value is String)
              r: e.value as String,
      },
      corrected: {
        if (json['corrected'] case final List l)
          for (final s in l) ?_parse(s),
      },
      inks: {
        if (json['inks'] case final Map m)
          for (final e in m.entries)
            if (mark(e.key) case final k? when e.value is int)
              k: e.value as int,
      },
    );
  }

  static String _ref(WordRef r) => '${r.ayahId}:${r.wordIndex}';

  static WordRef? _parse(Object? s) {
    if (s is! String) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final ayah = int.tryParse(parts[0]), word = int.tryParse(parts[1]);
    return ayah == null || word == null
        ? null
        : (ayahId: ayah, wordIndex: word);
  }

  Future<void> _write(String key, Map<String, Object?>? value) async {
    try {
      if (value == null) {
        await _storage.remove(key);
      } else {
        await _storage.setString(key, jsonEncode(value));
      }
    } catch (_) {
      // Not kept this time: the session itself goes on.
    }
  }

  Future<Map<String, Object?>?> _read(String key) async {
    try {
      final raw = await _storage.getString(key);
      final json = raw == null ? null : jsonDecode(raw);
      return json is Map<String, Object?> ? json : null;
    } catch (_) {
      return null;
    }
  }
}
