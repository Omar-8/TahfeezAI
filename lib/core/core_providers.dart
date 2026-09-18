import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audio/audio_controller.dart';
import 'audio/just_audio_controller.dart';
import 'database/app_database.dart';
import 'database/database_connection.dart';
import 'logging/app_logger.dart';
import 'logging/logging_package_logger.dart';
import 'networking/connectivity_service.dart';
import 'networking/network_client.dart';
import 'platform/platform_capabilities.dart';

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
AppLogger appLogger(Ref ref) => LoggingPackageLogger();

@Riverpod(keepAlive: true)
PlatformCapabilities platformCapabilities(Ref ref) =>
    const DefaultPlatformCapabilities();

@Riverpod(keepAlive: true)
NetworkClient networkClient(Ref ref) => DioNetworkClient();

@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) => ConnectivityPlusService();

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
AudioController audioController(Ref ref) {
  final controller = JustAudioController();
  ref.onDispose(controller.dispose);
  return controller;
}
