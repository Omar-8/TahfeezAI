import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/networking/network_client.dart';
import 'meaning_pack_store.dart';

/// [DownloadingMeaningPackStore]'s download through the app's
/// [NetworkClient]: no network (or none that answers) is
/// [MeaningPackOffline] — tried again once the phone is online; any other
/// failure (the server's answer) is an error, shown.
MeaningPackFetch meaningPackFetch(NetworkClient client) => (url, path) async {
  try {
    await client.download(url.toString(), path);
  } on DioException catch (e) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    switch (e.type) {
      case DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout:
        throw MeaningPackOffline(e.message ?? e.type.name);
      case DioExceptionType.unknown when e.error is SocketException:
        throw MeaningPackOffline(e.error!);
      case _:
        throw StateError(
          'Downloading $url failed: '
          '${e.response?.statusCode ?? e.type.name}',
        );
    }
  }
};
