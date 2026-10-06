import 'dart:convert';

import '../../../core/storage/browser_storage.dart';
import '../domain/recitation_session.dart';

/// Stores session metadata as one small JSON list in [BrowserStorage]
/// (SharedPreferences on Android, localStorage on the web).
///
/// Metadata only — a few hundred bytes per session — so this stays well
/// within what key/value storage is meant for. Capped at [maxSessions];
/// a history screen with search/filtering would move this to Drift.
class BrowserStorageRecitationSessionRepository
    implements RecitationSessionRepository {
  const BrowserStorageRecitationSessionRepository(this._storage);

  static const storageKey = 'recitation.sessions.v1';
  static const maxSessions = 200;

  final BrowserStorage _storage;

  @override
  Future<List<RecitationSession>> list() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final entry in decoded) ?RecitationSession.fromJson(entry)];
    } on FormatException {
      return [];
    }
  }

  @override
  Future<void> save(RecitationSession session) async {
    final sessions = [
      session,
      for (final existing in await list())
        if (existing.id != session.id) existing,
    ];
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _storage.setString(
      storageKey,
      jsonEncode([for (final s in sessions.take(maxSessions)) s.toJson()]),
    );
  }
}
