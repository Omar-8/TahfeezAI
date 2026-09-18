import 'package:path_provider/path_provider.dart';

/// Abstraction over the device filesystem locations Tahfeez needs.
///
/// UI and domain code must go through this interface instead of calling
/// `path_provider` directly, per `CLAUDE.md`'s "platform adapters rather
/// than platform checks scattered throughout widgets" rule. On the web,
/// there is no traditional filesystem; callers that need persistence on the
/// web should use [BrowserStorage] (`browser_storage.dart`) instead, or a
/// dedicated large-file strategy introduced by the Resource Manager
/// milestone (Origin Private File System / IndexedDB-backed blobs).
abstract class FileStorage {
  /// Durable, user-invisible app data (installed Quran resources, databases
  /// that are not part of the OS backup, downloaded audio/fonts/atlases).
  Future<String> appDataDirectoryPath();

  /// Cache data the OS may clear under storage pressure — safe to lose,
  /// should be treated as re-derivable/re-downloadable.
  Future<String> cacheDirectoryPath();

  /// Directory suitable for files the user explicitly exports (e.g. a
  /// bookmarks/settings export archive) before handing them to a share
  /// sheet or file picker.
  Future<String> temporaryExportDirectoryPath();
}

/// Default [FileStorage] implementation backed by `package:path_provider`.
///
/// Not available on the web — see the class-level doc on [FileStorage].
class PathProviderFileStorage implements FileStorage {
  const PathProviderFileStorage();

  @override
  Future<String> appDataDirectoryPath() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  Future<String> cacheDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<String> temporaryExportDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }
}
