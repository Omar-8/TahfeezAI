import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'browser_storage.dart';
import 'file_storage.dart';

part 'storage_providers.g.dart';

@Riverpod(keepAlive: true)
FileStorage fileStorage(Ref ref) => const PathProviderFileStorage();

@Riverpod(keepAlive: true)
BrowserStorage browserStorage(Ref ref) =>
    const SharedPreferencesBrowserStorage();
