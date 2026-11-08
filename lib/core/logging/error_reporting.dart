import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'recent_log.dart';

/// Wires Flutter/Dart's global error hooks into an [AppLogger].
///
/// Call this once during [bootstrap] (see `lib/app/bootstrap.dart`), before
/// `runApp`. Centralizing this here means feature code never needs its own
/// top-level error handling — uncaught framework errors and uncaught async
/// errors both funnel through the same [AppLogger] used everywhere else.
void installGlobalErrorReporting(AppLogger logger) {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    RecentLog.instance.add(
      'ERROR ${details.exceptionAsString()}\n'
      '${_firstLines(details.stack)}',
    );
    logger.error(
      details.summary.toString(),
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    RecentLog.instance.add('ERROR $error\n${_firstLines(stackTrace)}');
    logger.error(
      'Uncaught platform/async error',
      tag: 'PlatformDispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };
}

/// A stack's top, for [RecentLog]: where it happened, not all of it.
String _firstLines(StackTrace? stack, [int lines = 6]) =>
    (stack?.toString() ?? '').split('\n').take(lines).join('\n');
