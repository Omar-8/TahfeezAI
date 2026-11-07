import 'dart:io';

/// A local file's length in bytes; `null` when it cannot be read.
Future<int?> localFileLength(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return null;
  }
}
