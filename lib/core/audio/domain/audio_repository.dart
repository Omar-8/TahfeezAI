/// Domain-first interface over "what is there to listen to", independent of
/// playback engine or download mechanism.
///
/// Deliberately minimal for Milestone 1 — reciter rosters, verse-clip
/// timing, and translation-audio pairing (see
/// `docs/reference/08_AUDIO_SPEC.md`) are built out by the Audio milestone.
abstract class AudioRepository {
  /// Resolves a playable URL for a chapter's recitation by a given reciter,
  /// preferring a locally downloaded file over a network stream when one is
  /// available.
  Future<String?> resolveChapterAudioUrl({
    required String reciterId,
    required int chapterNo,
  });
}
