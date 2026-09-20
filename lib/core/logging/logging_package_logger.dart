import 'dart:developer' as developer;

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
  static bool _sinkAttached = false;

  LoggingPackageLogger() {
    pkg.hierarchicalLoggingEnabled = true;
    // `package:logging` records are otherwise held only in memory by each
    // `Logger` instance and never reach any visible output — every
    // `AppLogger` call in the app (including BundledDatasetSeeder's import
    // diagnostics) would silently produce nothing in `adb logcat` or
    // `flutter logs`. `dart:developer`'s `log()` is what both surface.
    // Guarded by a static flag since `Logger.root.onRecord` is a
    // process-wide broadcast stream: without it, constructing a second
    // `LoggingPackageLogger` would double- (or N-)register listeners and
    // print every record multiple times.
    if (!_sinkAttached) {
      _sinkAttached = true;
      pkg.Logger.root.level = pkg.Level.ALL;
      pkg.Logger.root.onRecord.listen((record) {
        developer.log(
          record.message,
          time: record.time,
          level: record.level.value,
          name: record.loggerName,
          error: record.error,
          stackTrace: record.stackTrace,
        );
      });
    }
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
