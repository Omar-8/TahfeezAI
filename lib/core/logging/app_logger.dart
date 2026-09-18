/// Application-wide logging abstraction.
///
/// UI, domain, and data code depend on this interface, never on a specific
/// logging package directly — this is what lets Tahfeez later swap in (or
/// add) a self-hosted diagnostics/log-export feature (the reference app's
/// "App Logs" screen, `docs/reference/16_PLATFORM_FEATURES_SPEC.md` §5)
/// without touching call sites, and keeps Tahfeez's stated no-third-party-
/// analytics posture (`docs/PROJECT_BRIEF.md`) enforceable in one place.
abstract class AppLogger {
  void debug(String message, {String? tag});
  void info(String message, {String? tag});
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  });
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  });
}
