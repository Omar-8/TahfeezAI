import 'package:logging/logging.dart' as pkg;

import 'app_logger.dart';

/// [AppLogger] implementation backed by `package:logging`.
///
/// Kept deliberately simple for the foundation milestone: it forwards to
/// `dart:developer`-visible loggers via `package:logging`'s root logger.
/// A later milestone can add a second [AppLogger] implementation that also
/// persists records to disk for an in-app log viewer, without changing any
/// call site, because everything depends on [AppLogger].
class LoggingPackageLogger implements AppLogger {
  LoggingPackageLogger() {
    pkg.hierarchicalLoggingEnabled = true;
  }

  pkg.Logger _loggerFor(String? tag) => pkg.Logger(tag ?? 'tahfeez');

  @override
  void debug(String message, {String? tag}) => _loggerFor(tag).fine(message);

  @override
  void info(String message, {String? tag}) => _loggerFor(tag).info(message);

  @override
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _loggerFor(tag).warning(message, error, stackTrace);
  }

  @override
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _loggerFor(tag).severe(message, error, stackTrace);
  }
}
