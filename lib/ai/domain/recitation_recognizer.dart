import 'recitation_models.dart';

/// Replaceable contract for a future live-recitation recognition engine.
///
/// Per Milestone 1's scope, **no implementation of this exists yet** — this
/// interface only reserves the shape so `lib/memorization/` can be designed
/// against a stable AI boundary from the start (`docs/PROJECT_BRIEF.md`
/// notes the app "should be useful even if the AI features are never
/// enabled", which this seam makes structurally easy: any concrete
/// [RecitationRecognizer] is optional and swappable, including a possible
/// on-device implementation later).
abstract class RecitationRecognizer {
  /// Recognition events for the currently active session, if any.
  Stream<RecitationEvent> get events;

  Future<void> start(RecitationContext context);

  Future<void> stop();
}
