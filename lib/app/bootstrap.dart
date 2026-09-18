import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/error_reporting.dart';
import '../core/logging/logging_package_logger.dart';
import 'app.dart';

/// Single, explicit startup sequence for Tahfeez AI.
///
/// Kept separate from `main()` so alternate entry points (tests, future
/// build flavors) can reuse it without duplicating setup order. Order
/// matters: bindings must be initialized before any plugin channel is
/// touched, and global error reporting must be installed before [runApp]
/// so it can catch errors thrown during the very first frame.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = LoggingPackageLogger();
  installGlobalErrorReporting(logger);

  runApp(const ProviderScope(child: TahfeezApp()));
}
