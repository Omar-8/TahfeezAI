import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/quran_location_path.dart';

/// A finished (or in-progress) live recitation session: one continuous
/// microphone session recorded as one audio file.
///
/// Mutable user data — kept entirely separate from the immutable Quran
/// dataset. [startLocation] is only where the reciter began; it says
/// nothing about what they actually recited (that is the recognizer's job
/// in a later milestone).
class RecitationSession {
  const RecitationSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.duration = Duration.zero,
    this.recordingReference,
    this.startLocation,
  });

  final String id;
  final DateTime startedAt;

  /// `null` while the session is still running.
  final DateTime? endedAt;

  /// Time actually spent listening — paused intervals are excluded, so
  /// this matches the length of the recording, not `endedAt - startedAt`.
  final Duration duration;

  /// Where the recording lives: a file path on Android, an object URL on
  /// the web. `null` if nothing was kept.
  final String? recordingReference;

  /// The Mushaf page the session was started from, if known.
  final QuranLocation? startLocation;

  RecitationSession copyWith({
    DateTime? endedAt,
    Duration? duration,
    String? recordingReference,
  }) {
    return RecitationSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      recordingReference: recordingReference ?? this.recordingReference,
      startLocation: startLocation,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'recording': recordingReference,
    'startLocation': startLocation == null
        ? null
        : quranLocationPath(startLocation!),
  };

  /// Returns `null` for malformed input rather than throwing, so one bad
  /// stored entry can't hide every other session.
  static RecitationSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final startedAt = DateTime.tryParse('${json['startedAt']}');
    if (id is! String || startedAt == null) return null;
    final endedAtRaw = json['endedAt'];
    final durationMs = json['durationMs'];
    final recording = json['recording'];
    final location = json['startLocation'];
    return RecitationSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAtRaw is String ? DateTime.tryParse(endedAtRaw) : null,
      duration: Duration(milliseconds: durationMs is int ? durationMs : 0),
      recordingReference: recording is String ? recording : null,
      startLocation: location is String
          ? quranLocationFromPath(location)
          : null,
    );
  }

  @override
  String toString() =>
      'RecitationSession($id, $startedAt → $endedAt, $duration, '
      '$recordingReference, $startLocation)';
}

/// Persists session metadata (not the audio itself).
abstract class RecitationSessionRepository {
  /// Most recent first.
  Future<List<RecitationSession>> list();

  /// Inserts or replaces the session with the same id.
  Future<void> save(RecitationSession session);
}
